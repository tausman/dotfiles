#!/usr/bin/env bash
# One-shot setup for the nix-managed Ubuntu VM (user: bits).
#
# Do these BY HAND first (they can't/shouldn't be automated here):
#   1. Clone this repo:   git clone https://github.com/tausman/dotfiles.git ~/dotfiles
#   2. GitHub auth:       ./install.sh auth      (both accounts, keys, signing, SSO)
#   3. git-config-tool:   curl -fsSL https://binaries.ddbuild.io/devtools/apps/git-config-tool/install.sh | sh
#                         git-config-tool setup --no-signing --no-1password
#      (wires the ddoghq.github.com ssh alias — the datadog-pi-packages clone below
#       fails without it.)
#
# Then run this script. It is idempotent — safe to re-run:
#   - installs Nix if it isn't already present (Determinate Systems installer),
#   - applies the home-manager config for THIS machine's architecture,
#   - configures the DD repos, Claude plugins, and pi.
#
# Unlike install.sh (apt + linuxbrew + stow), this assumes nix/home-manager owns the
# tools and dotfiles, so there is no brew/stow/base/volta here.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
FLAKE_DIR="$DOTFILES_DIR/nix-config"

# Nix subcommands need the flakes + nix-command features. The Determinate installer
# turns these on globally, but pass them explicitly so this also works under the
# upstream installer or a locked-down nix.conf.
NIX_FLAGS=(--extra-experimental-features "nix-command flakes")

# Wire `nix` into THIS shell. Source the daemon profile whenever it exists — even if
# `nix` is already on PATH — because it sets both PATH *and* NIX_REMOTE=daemon. That env
# var is the critical bit: without it a non-root user bypasses the daemon and tries the
# root-only local store, failing with `big-lock: Permission denied`. A non-login shell
# (`bash install_nix.sh`) doesn't source it on its own, hence doing it here. Returns 0 if
# nix ends up callable.
load_nix() {
    local p
    for p in \
        /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
        "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
        # shellcheck disable=SC1090
        [ -e "$p" ] && . "$p"
    done
    command -v nix >/dev/null 2>&1
}

ensure_nix() {
    if load_nix; then
        echo "Nix already installed: $(command -v nix)"
        return 0
    fi
    echo "Nix not found — installing (Determinate Systems installer)..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
    load_nix || {
        echo "ERROR: nix installed but not on PATH. Open a NEW shell and re-run this script." >&2
        exit 1
    }
    echo "Nix installed: $(command -v nix)"
}

# Confirm the Nix daemon is actually reachable before we try to switch. Turns the cryptic
# "big-lock: Permission denied" / "daemon may have crashed" into an actionable message,
# covering both "just installed, this shell isn't wired up yet" and "daemon not running".
require_daemon() {
    if nix "${NIX_FLAGS[@]}" store ping >/dev/null 2>&1; then
        return 0
    fi
    cat >&2 <<'EOF'
ERROR: can't reach the Nix daemon (non-root nix needs it).
Most likely one of:
  1. Nix was JUST installed and this shell isn't wired to the daemon yet
     -> open a NEW shell (fresh login) as your normal user, then re-run ./install_nix.sh
  2. The daemon isn't running
     -> sudo systemctl enable --now nix-daemon.socket nix-daemon.service
        (Determinate builds: sudo systemctl enable --now determinate-nixd.socket)
Verify it's up with:  nix store ping
EOF
    exit 1
}

# Map this machine's arch to the matching flake home configuration.
home_target() {
    case "$(uname -m)" in
        aarch64|arm64) echo "ubuntu-aarch64" ;;
        x86_64|amd64)  echo "ubuntu-x86_64" ;;
        *) echo "ERROR: unsupported architecture '$(uname -m)'" >&2; exit 1 ;;
    esac
}

apply_home_manager() {
    local target; target="$(home_target)"
    echo "Applying home-manager config: #$target"
    # `nix run home-manager` works both first-time and after (home-manager also
    # installs itself into the profile). -b backup renames any pre-existing files
    # that would otherwise block the switch (e.g. a stock ~/.zshrc on the VM).
    nix "${NIX_FLAGS[@]}" run home-manager -- switch -b backup --flake "$FLAKE_DIR#$target"
    # Our shell predates the switch. Put the new profile bins on PATH, then source the
    # session vars home-manager just generated (NPM_CONFIG_PREFIX, sessionPath, …) so the
    # rest of this run uses exactly what nix configured — nothing is hardcoded here.
    export PATH="$HOME/.nix-profile/bin:$PATH"
    local hm_vars="$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    if [ -e "$hm_vars" ]; then
        # Clear the guard so the freshly-generated vars load even if a parent shell
        # already sourced an older generation.
        unset __HM_SESS_VARS_SOURCED
        # shellcheck disable=SC1090
        . "$hm_vars"
    fi
}

# DD repos: clone the standalone ones and configure fetch/jj on any monorepos that
# already exist. Delegated to install.sh, whose `repos` step is OS-agnostic (git/jj).
setup_repos() {
    echo "Configuring DD repos..."
    "$DOTFILES_DIR/install.sh" repos
}

# Claude plugins. claude-code itself is nix-managed (home.packages), so this skips
# `claude install` and only wires the marketplace + plugin. Mirrors install.sh's
# setup_claude otherwise.
setup_claude() {
    echo "Setting up Claude plugins..."
    local plugins_repo="git@github.com:tausman/claude-plugins.git"
    local plugins_dir="$HOME/claude-plugins"
    [ -d "$plugins_dir/.git" ] || git clone "$plugins_repo" "$plugins_dir"
    if [ ! -d "$plugins_dir/.jj" ]; then
        ( cd "$plugins_dir" && jj git init --colocate )
    fi
    # Both commands exit non-zero if already present (would abort under `set -e`), so
    # guard each on a presence check.
    claude plugin marketplace list 2>/dev/null | grep -q '\btausman\b' || \
        claude plugin marketplace add "$plugins_repo"
    claude plugin list 2>/dev/null | grep -q 'tausman@tausman' || \
        claude plugin install tausman@tausman
    echo "Claude setup complete."
}

# pi coding agent. node/npm come from nix; NPM_CONFIG_PREFIX is set by home-manager
# (modules/zsh.nix) and sourced in apply_home_manager, so `npm install -g` lands in
# ~/.local/bin instead of failing on the read-only /nix/store.
setup_pi() {
    echo "Setting up pi..."
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent
    echo "pi setup complete."
}

main() {
    # home-manager activates as $USER and refuses if it doesn't match home.username
    # ("bits"). Running under sudo/root is therefore always wrong here.
    if [ "$(id -u)" -eq 0 ]; then
        echo "ERROR: run this as your normal user (bits), NOT root/sudo." >&2
        echo "       home-manager activates as \$USER and errors if USER != bits." >&2
        exit 1
    fi
    ensure_nix
    require_daemon
    apply_home_manager
    setup_repos
    setup_claude
    setup_pi
    echo
    echo "Done. Open a fresh shell ('exec zsh -l') so PATH/session vars refresh."
}

main "$@"
