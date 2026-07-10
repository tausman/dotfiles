#!/usr/bin/env bash
# Self-contained setup for the nix-managed machines (the Ubuntu VM `bits`, and the mac).
# This is the NEW installer and does NOT depend on install.sh: nix/home-manager own the
# tools and dotfiles; this script does the one-time, non-nix work — the ssh Include, repos,
# Claude plugins, pi, web-ui, and dogweb. It runs fully non-interactively, end to end.
#
# Do these BY HAND first:
#   1. Clone this repo:   git clone https://github.com/tausman/dotfiles.git ~/dotfiles
#   2. GitHub auth:       ./install.sh auth      (both accounts, keys, signing, SSO)
#   3. git-config-tool:   curl -fsSL https://binaries.ddbuild.io/devtools/apps/git-config-tool/install.sh | sh
#                         git-config-tool setup --no-signing --no-1password
#      (wires the ddoghq.github.com ssh alias — the datadog-pi-packages clone needs it.)
#
# No brew anywhere: volta and watchman come from nix (modules/nodejs.nix). The web-ui and
# dogweb steps assume, like the workspace, that a Docker daemon and direnv are available and
# that the dd-source/dd-go/dogweb/web-ui monorepos already exist under ~/dd.
# Idempotent — safe to re-run.
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
    # Also put volta's shim dir up front: it's where volta's nix-managed `node`/`npm` land,
    # and a non-interactive shell doesn't get it from the dotfiles .zshenv. web-ui's pinned
    # Node resolves through here.
    export PATH="$HOME/.volta/bin:$HOME/.nix-profile/bin:$PATH"
    local hm_vars="$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    if [ -e "$hm_vars" ]; then
        # Clear the guard so the freshly-generated vars load even if a parent shell
        # already sourced an older generation.
        unset __HM_SESS_VARS_SOURCED
        # shellcheck disable=SC1090
        . "$hm_vars"
    fi
}

# Colocate jj in the dotfiles repo itself so it's usable with the jj workflow like the DD
# repos (jj errors on re-init, so guard on the .jj dir).
colocate_dotfiles() {
    if [ ! -d "$DOTFILES_DIR/.jj" ]; then
        echo "Colocating jj in $DOTFILES_DIR..."
        ( cd "$DOTFILES_DIR" && jj git init --colocate )
    fi
}

# DD repos: clone the standalone repos (team-aaa, pi-packages), then narrow the fetch
# refspec to the default branch + tausman/* and colocate jj on every repo that exists. The
# big monorepos (dd-source/dd-go/dogweb/web-ui) are provisioned separately and only
# configured here if present. Self-contained (git/jj only) — no install.sh dependency.
setup_repos() {
    echo "Configuring DD repos..."

    [ -d "$HOME/dd/team-aaa-internal-tools/.git" ] || \
        git clone git@github.com:DataDog/team-aaa-internal-tools.git "$HOME/dd/team-aaa-internal-tools"
    # Expose the acepg postgres-access helper on PATH.
    mkdir -p "$HOME/.local/bin"
    ln -sf "$HOME/dd/team-aaa-internal-tools/postgres-access-tool/acepg" "$HOME/.local/bin/acepg"

    # pi coding-agent packages live in the ddoghq-sandbox org (needs git-config-tool export).
    [ -d "$HOME/dd/datadog-pi-packages/.git" ] || \
        git clone git@github.com:ddoghq-sandbox/datadog-pi-packages.git "$HOME/dd/datadog-pi-packages"

    local repo default_branch
    for repo in "$HOME"/dd/dd-source "$HOME"/dd/dd-go "$HOME"/dd/dogweb "$HOME"/dd/web-ui \
                "$HOME"/dd/team-aaa-internal-tools "$HOME"/dd/datadog-pi-packages; do
        if [ ! -d "$repo/.git" ]; then
            echo "  Skipping $repo (not a git repo)"
            continue
        fi
        echo "Configuring $repo..."
        cd "$repo"

        default_branch=$(git ls-remote --symref origin HEAD | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2}')
        if [ -z "$default_branch" ]; then
            echo "  Could not determine default branch, skipping"
            continue
        fi
        echo "  Default branch: $default_branch"

        # Reset remote tracking refs, then track only the default branch + tausman/*.
        git symbolic-ref --delete refs/remotes/origin/HEAD 2>/dev/null || true
        git for-each-ref --format='delete %(refname)' refs/remotes/origin/ | git update-ref --stdin 2>/dev/null || true
        git config --unset-all remote.origin.fetch 2>/dev/null || true
        git config --add remote.origin.fetch "+refs/heads/${default_branch}:refs/remotes/origin/${default_branch}"
        git config --add remote.origin.fetch '+refs/heads/tausman*:refs/remotes/origin/tausman*'
        git fetch origin

        [ -d .jj ] || jj git init --colocate
        echo "  Done."
    done
    echo "Repo setup complete."
}

# Our custom ssh config (custom/github-keys.config, linked by nix) only loads if
# ~/.ssh/config Includes it. Add that include once, idempotently, prepended so it sits above
# any Host block. Any existing ~/.ssh/config is preserved verbatim.
ensure_ssh_custom_include() {
    local cfg="$HOME/.ssh/config"
    mkdir -p "$HOME/.ssh"
    touch "$cfg"
    if grep -qF 'Include ~/.ssh/custom/*' "$cfg"; then
        echo "ssh config already includes ~/.ssh/custom/*"
        return
    fi
    local tmp="$cfg.tmp.$$"
    { echo 'Include ~/.ssh/custom/*'; echo; cat "$cfg"; } > "$tmp"
    cat "$tmp" > "$cfg"
    rm -f "$tmp"
    echo "Added 'Include ~/.ssh/custom/*' to ~/.ssh/config."
}

# Claude plugins. claude-code itself is nix-managed (home.packages), so this skips
# `claude install` and only wires the marketplace + plugin.
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

setup_web_ui() {
    echo "Setting up web-ui..."
    cd "$HOME/dd/web-ui"

    # Install the exact Node web-ui pins (.node-version). volta (nix-managed) auto-selects it
    # inside this repo; ~/.volta/bin is on PATH (set in apply_home_manager) so its shims win.
    # We don't set a global volta default — nix's node covers general use.
    volta install "node@$(cat .node-version)"

    # Yarn Switch (per-project yarn version manager).
    curl -sS https://repo.yarnpkg.com/install | bash
    export PATH="$HOME/.yarn/switch/bin:$PATH"
    # Drop volta's yarn shims so yarn-switch's yarn wins on PATH.
    rm -f "$HOME/.volta/bin/yarn" "$HOME/.volta/bin/yarnpkg"

    # Large monorepo install; retry to ride out flaky registry fetches.
    local attempt ok=0
    for attempt in 1 2 3; do
        if yarn install; then ok=1; break; fi
        echo "  yarn install failed (attempt $attempt/3), retrying in 5s..."
        sleep 5
    done
    [ "$ok" -eq 1 ] || { echo "ERROR: yarn install failed after 3 attempts" >&2; exit 1; }

    bash ./dev/ssl/generate_and_trust_localhost_certificate.sh
    # watchman comes from nix (no brew install here).

    git config remote.origin.tagOpt --no-tags
    git config remote.origin.prune true

    bash doctor
    echo "web-ui setup complete."
}

setup_dogweb() {
    echo "Setting up dogweb..."
    cd "$HOME/dd/dogweb"

    # Bring up dogweb's local service dependencies before update_deps wires them together.
    # `dd-compose` is an interactive alias, so point docker-compose directly at the workspace
    # compose file shipped in dd-source.
    docker-compose -f \
        "$HOME/dd/dd-source/domains/devex/workspaces/apps/shell-image/etc/container-config/compose.yaml" \
        up -d --wait

    # update_deps is provided by dogweb's direnv env, not the base PATH — run it through
    # `direnv exec` so it resolves non-interactively (falls back to a bare call otherwise).
    # direnv refuses a `.envrc` that hasn't been approved, so allow it first (it's your own
    # dogweb clone, and you're explicitly setting it up here). ~/dd is a symlink into
    # ~/go/src, and direnv keys approval by path — so allow AND exec must use the SAME
    # physical path, or the .envrc stays "blocked".
    if command -v direnv >/dev/null 2>&1; then
        local dogweb; dogweb="$(cd "$HOME/dd/dogweb" && pwd -P)"
        direnv allow "$dogweb"
        direnv exec "$dogweb" update_deps
    else
        update_deps
    fi
    echo "dogweb setup complete."
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
    ensure_ssh_custom_include        # nix links ~/.ssh/custom/*; this makes ssh load it
    mkdir -p "$HOME/vaults/work"     # obsidian vault dir (was in install.sh setup_base)
    colocate_dotfiles
    setup_repos
    setup_claude
    setup_pi
    setup_web_ui
    setup_dogweb
    echo
    echo "Done. Open a fresh shell ('exec zsh -l') so PATH/session vars refresh."
    cat <<'EOF'
    DON'T FORGET (run on your Mac host, to trust web-ui's localhost cert):
    scp <this-host>:~/.config/datadog/dev-ssl/localhost.crt ~
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/localhost.crt
EOF
}

main "$@"
