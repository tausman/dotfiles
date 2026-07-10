#!/usr/bin/env bash
# Self-contained setup for the nix-managed machines (the Ubuntu VM `bits`, and the mac).
# This is the NEW installer and does NOT depend on install.sh: nix/home-manager own the
# tools and dotfiles; this script does the one-time, non-nix work — the ssh Include, repos,
# Claude plugins, pi, web-ui, and dogweb. It runs fully non-interactively, end to end.
#
# Do these first:
#   1. Clone this repo:   git clone https://github.com/tausman/dotfiles.git ~/dotfiles
#   2. GitHub auth:       ./install_nix.sh auth   (both accounts, keys, signing, SSO)
#   3. git-config-tool:   curl -fsSL https://binaries.ddbuild.io/devtools/apps/git-config-tool/install.sh | sh
#                         git-config-tool setup --no-signing --no-1password
#      (wires the ddoghq.github.com ssh alias — the datadog-pi-packages clone needs it.)
#
# No brew anywhere: volta and watchman come from nix (modules/nodejs.nix). The web-ui and
# dogweb steps assume, like the workspace, that a Docker daemon and direnv are available and
# that the dd-source/dd-go/dogweb/web-ui monorepos already exist under ~/dd.
# Idempotent — safe to re-run.
#
# Usage:
#   ./install_nix.sh          full setup (everything except auth)
#   ./install_nix.sh fast     full setup minus the heavy web-ui + dogweb steps
#   ./install_nix.sh nix      just install Nix + verify the daemon, then stop
#   ./install_nix.sh auth     GitHub auth only (both accounts, keys, signing, SSO)
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
# covering both "just installed, this shell isn't wired to the daemon yet" and "daemon not
# running" — and, on hosts with no systemd (e.g. a Datadog workspace container, where PID 1
# is a plain keep-alive process and every other daemon — cron, caddy, bees-monitor — is a
# manually-backgrounded process, not a unit), starts nix-daemon by hand instead of relying on
# systemctl. The Determinate installer still writes systemd units there (it only checks for
# the systemctl binary on disk, not whether systemd is actually PID 1), so those units would
# otherwise sit forever unstarted.
require_daemon() {
    if nix "${NIX_FLAGS[@]}" store ping >/dev/null 2>&1; then
        return 0
    fi

    echo "Nix daemon not reachable — attempting to start it..."
    if [ "$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]; then
        sudo systemctl enable --now nix-daemon.socket nix-daemon.service 2>/dev/null || \
            sudo systemctl enable --now determinate-nixd.socket 2>/dev/null || true
    else
        sudo mkdir -p /var/log
        sudo bash -c "setsid nohup $(command -v nix-daemon) >/var/log/nix-daemon.log 2>&1 </dev/null &"
        sleep 2
    fi

    if nix "${NIX_FLAGS[@]}" store ping >/dev/null 2>&1; then
        echo "Nix daemon is up."
        return 0
    fi

    cat >&2 <<'EOF'
ERROR: can't reach the Nix daemon (non-root nix needs it).
Most likely one of:
  1. Nix was JUST installed and this shell isn't wired to the daemon yet
     -> open a NEW shell (fresh login) as your normal user, then re-run ./install_nix.sh
  2. The daemon failed to start
     -> systemd hosts:    sudo systemctl status nix-daemon.service
     -> non-systemd hosts: check /var/log/nix-daemon.log
Verify it's up with:  nix store ping
EOF
    exit 1
}

# GitHub auth + keys for both accounts (tausman and the tausif-rahman_ddog managed
# identity). Generates a per-machine keypair for each account, uploads the public halves
# (auth for both, signing for tausman), records signing trust, and walks through SSO. Ported
# from install.sh; OS-agnostic (gh + ssh-keygen). Idempotent — existing keys/uploads/scopes
# are detected and skipped. Private keys never leave the machine.
setup_auth() {
    echo "Setting up GitHub auth + signing keys..."
    command -v gh >/dev/null 2>&1 || {
        echo "ERROR: gh (GitHub CLI) not found — install it first." >&2
        exit 1
    }

    # `timeout` guards the SSO probe from hanging. macOS lacks it, so fall back to
    # coreutils' gtimeout, or run without a limit.
    run_timeout() {  # run_timeout <secs> <cmd...>
        if command -v timeout >/dev/null 2>&1; then timeout "$@"
        elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$@"
        else shift; "$@"; fi
    }

    # Both accounts must be logged in: the primary (tausman) and the Datadog managed
    # identity (tausif-rahman_ddog). Verify each by name and only run the flow for a missing
    # one. -w opens a browser, -c copies the code.
    for acct in tausman tausif-rahman_ddog; do
        if gh auth status 2>/dev/null | grep -q "account $acct"; then
            echo "gh: $acct already logged in."
        else
            echo "gh: $acct not logged in — starting login flow."
            echo "  >>> Authenticate as $acct in the browser <<<"
            gh auth login -h github.com -p ssh --skip-ssh-key -w -c
            gh auth status 2>/dev/null | grep -q "account $acct" || {
                echo "ERROR: still not logged in as $acct (did you pick the right account?)." >&2
                exit 1
            }
        fi
    done

    ensure_scope() {  # ensure_scope <scope>
        gh auth status --active 2>&1 | grep -q "'$1'" || {
            echo "  Adding token scope '$1' (opens browser)..."
            gh auth refresh -h github.com -s "$1"
        }
    }
    key_on_account() {  # key_on_account <pubfile> <api-path> — already uploaded?
        gh api "$2" --jq '.[].key' 2>/dev/null | grep -qF "$(awk '{print $1, $2}' "$1")"
    }
    upload_key() {  # upload_key <pubfile> <authentication|signing>
        local api=/user/keys; [ "$2" = signing ] && api=/user/ssh_signing_keys
        if key_on_account "$1" "$api"; then
            echo "  $2 key already uploaded — skipping."
        else
            gh ssh-key add "$1" --type "$2" --title "$(hostname -s) $(basename "$1") ($2)"
            echo "  Uploaded $2 key ($(basename "$1"))."
        fi
    }
    key_can_access() {  # key_can_access <keyfile> <owner/repo> — SSO-authorized + access?
        run_timeout 20 ssh -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new \
            -i "$1" git@github.com "git-upload-pack '$2.git'" </dev/null >/dev/null 2>&1
    }
    ensure_sso() {  # ensure_sso <account> <keyfile> <org> <owner/repo>
        if key_can_access "$2" "$4"; then
            echo "  SSO OK: $(basename "$2") can reach $4."
            return 0
        fi
        if [ ! -t 0 ]; then
            echo "  WARNING: $(basename "$2") can't reach $4 — authorize '$3' at" >&2
            echo "           https://github.com/settings/keys (non-interactive; skipping)." >&2
            return 0
        fi
        echo
        echo "  >>> SSO NEEDED for $1 <<<"
        echo "  Key '$(basename "$2")' isn't authorized for the '$3' org yet."
        echo "    1. Open   https://github.com/settings/keys"
        echo "    2. Find   '$(hostname -s) $(basename "$2") (authentication)'"
        echo "    3. Click  'Configure SSO' and authorize '$3'."
        while true; do
            read -r -p "  Press Enter to re-check (or 's' to skip): " ans || ans=s
            [ "$ans" = s ] && { echo "  Skipped SSO for $1 — git over this key may fail while the lid is closed."; return 0; }
            if key_can_access "$2" "$4"; then
                echo "  Verified: $(basename "$2") can now reach $4."
                return 0
            fi
            echo "  Still no access — confirm you authorized '$3' for this exact key."
        done
    }
    setup_account_key() {  # setup_account_key <account> <keyfile> <sign|nosign> <org> <owner/repo>
        echo "Setting up SSH key for $1..."
        gh auth switch -h github.com -u "$1"
        ensure_scope admin:public_key
        [ -f "$2" ] || ssh-keygen -t ed25519 -C "tausif.rahman@datadoghq.com" -f "$2" -N ""
        upload_key "$2.pub" authentication
        if [ "$3" = sign ]; then
            ensure_scope admin:ssh_signing_key
            upload_key "$2.pub" signing
        fi
        ensure_sso "$1" "$2" "$4" "$5"
    }

    setup_account_key tausman            ~/.ssh/id_ed25519_tausman sign   DataDog        DataDog/team-aaa-internal-tools
    setup_account_key tausif-rahman_ddog ~/.ssh/id_ed25519_ddog    nosign ddoghq-sandbox ddoghq-sandbox/datadog-pi-packages

    # Trust the signing key locally so jj/git can verify our own commits.
    mkdir -p ~/.ssh
    grep -qF "$(cat ~/.ssh/id_ed25519_tausman.pub)" ~/.ssh/allowed_signers 2>/dev/null || \
        echo "tausif.rahman@datadoghq.com $(cat ~/.ssh/id_ed25519_tausman.pub)" >> ~/.ssh/allowed_signers

    # Leave the Datadog managed identity active.
    gh auth switch -h github.com -u tausif-rahman_ddog
    echo "gh accounts + keys OK."
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

usage() {
    cat >&2 <<EOF
Usage: $0 [command]
  (none)   full setup: nix + home-manager + ssh + repos + claude + pi + web-ui + dogweb
  fast     full setup minus the heavy web-ui + dogweb steps
  nix      install Nix + verify the daemon, then stop
  auth     GitHub auth only (both accounts, per-account SSH keys, signing, SSO)
EOF
    exit 1
}

main() {
    local cmd="${1:-full}"
    case "$cmd" in full|fast|nix|auth) ;; *) usage ;; esac

    # Everything here runs as the normal user, never sudo/root: `auth` writes YOUR ssh keys,
    # the Determinate installer escalates on its own, and home-manager activates as $USER
    # (and refuses if it doesn't match home.username).
    if [ "$(id -u)" -eq 0 ]; then
        echo "ERROR: run this as your normal user, NOT root/sudo." >&2
        exit 1
    fi

    # Standalone commands.
    case "$cmd" in
        auth)
            setup_auth
            return 0
            ;;
        nix)
            ensure_nix
            require_daemon
            echo "Nix installed and daemon reachable."
            return 0
            ;;
    esac

    # full / fast
    ensure_nix
    require_daemon
    apply_home_manager
    ensure_ssh_custom_include        # nix links ~/.ssh/custom/*; this makes ssh load it
    mkdir -p "$HOME/vaults/work"     # obsidian vault dir (was in install.sh setup_base)
    colocate_dotfiles
    setup_repos
    setup_claude
    setup_pi

    if [ "$cmd" = fast ]; then
        echo
        echo "Fast mode: skipped web-ui and dogweb setup."
        echo "Done. Open a fresh shell ('exec zsh -l') so PATH/session vars refresh."
        return 0
    fi

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
