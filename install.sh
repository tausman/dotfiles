#!/usr/bin/env bash
# Run order: init -> move_originals -> stow -> base -> repos -> web-ui -> dogweb
set -e

# Make brew non-interactive: skip auto-update, "Press RETURN" prompts, and the
# "Do you want to proceed?" confirmation for installs with many dependencies
export HOMEBREW_NO_AUTO_UPDATE=1
export NONINTERACTIVE=1
export HOMEBREW_NO_ASK=1

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

PACKAGES=(
    claude
    config
    git
    jj
    scripts
    ssh
    tmux
    zshrc
)

move_originals() {
    echo "Moving original files..."
    [ -f ~/.zshrc ] && mv ~/.zshrc ~/.zshrc_original
    [ -f ~/.zshenv ] && mv ~/.zshenv ~/.zshenv_original
    [ -f ~/.claude/settings.json ] && mv ~/.claude/settings.json ~/.claude/settings_original.json
    [ -f ~/.gitconfig ] && mv ~/.gitconfig ~/.gitconfig_original
    [ -f ~/.tmux.conf ] && mv ~/.tmux.conf ~/.tmux_original.conf
    echo "Done moving originals."
}

# Our custom ssh config (custom/github-keys.config) only takes effect if
# ~/.ssh/config Includes it. The laptop gets an `Include ~/.ssh/workspaces/*` from
# the workspaces CLI, but the workspace host has no such include — so ssh never
# reads our fallback identities and git breaks when the forwarded agent is gone.
# ssh has no auto-included drop-in dir, so add the Include ourselves: once,
# idempotently (skip if grep already finds it), prepended so it sits at top level
# (before any Host block) and our on-disk keys are offered ahead of the managed
# ghkeys. Any existing ~/.ssh/config is preserved verbatim (contents and perms).
ensure_ssh_custom_include() {
    local cfg="$HOME/.ssh/config"
    mkdir -p "$HOME/.ssh"
    touch "$cfg"
    if grep -qF 'Include ~/.ssh/custom/*' "$cfg"; then
        echo "ssh config already includes ~/.ssh/custom/*"
        return
    fi
    # Prepend the include. Build the new file in a temp, then overwrite in place
    # (`cat > "$cfg"`, not mv) so the original file's mode/inode are kept.
    local tmp="$cfg.tmp.$$"
    { echo 'Include ~/.ssh/custom/*'; echo; cat "$cfg"; } > "$tmp"
    cat "$tmp" > "$cfg"
    rm -f "$tmp"
    echo "Added 'Include ~/.ssh/custom/*' to ~/.ssh/config."
}

stow_packages() {
    brew install stow
    cd ~/dotfiles
    for pkg in "${PACKAGES[@]}"; do
        echo "Stowing $pkg..."
        if [ "$pkg" = "jj" ] || [ "$pkg" = "ssh" ]; then
            stow -R -d "$DOTFILES_DIR" -t "$HOME" --dotfiles --no-folding "$pkg"
        else
            stow -R -d "$DOTFILES_DIR" -t "$HOME" --dotfiles "$pkg"
        fi
    done
    # Make the stowed custom/ ssh config actually load (add the Include if needed).
    ensure_ssh_custom_include
    echo "Done stowing packages."
    # Reload tmux config into any running server so changes take effect without
    # restarting tmux (no-op if no server is running).
    tmux source-file ~/.tmux.conf 2>/dev/null || true
    echo "Run: source ~/.zshrc"
}

# Repos are migrating from the DataDog GitHub org to the new ddoghq org, so on
# the workspace their checkouts live under ~/go/src/github.com/ddoghq/. Tooling
# (and ~/dd, a symlink to .../DataDog) still references them at the DataDog path,
# so symlink each ddoghq repo into the DataDog tree. Done generically — every
# directory under ddoghq/ is linked, so future migrations are picked up with no
# code change. If a repo exists as a real checkout in BOTH orgs the situation is
# ambiguous, so bail and let the user remove the stale DataDog copy.
link_ddoghq_repos() {
    echo "Linking ddoghq repos into the DataDog tree..."
    local ddoghq_dir="$HOME/go/src/github.com/ddoghq"
    local datadog_dir="$HOME/go/src/github.com/DataDog"

    if [ ! -d "$ddoghq_dir" ]; then
        echo "  No $ddoghq_dir — nothing to link."
        return
    fi

    local src name dst
    for src in "$ddoghq_dir"/*; do
        [ -d "$src" ] || continue          # only repo directories
        name=$(basename "$src")
        dst="$datadog_dir/$name"

        if [ -L "$dst" ]; then
            # Our own symlink from a previous run — repoint it (idempotent).
            ln -sfn "$src" "$dst"
            echo "  Relinked $name -> ddoghq"
        elif [ -e "$dst" ]; then
            # A real DataDog checkout coexists with the ddoghq one — ambiguous.
            cat >&2 <<EOF

ERROR: '$name' exists as a real checkout in BOTH orgs:
  ddoghq:  $src
  DataDog: $dst
This repo has migrated to ddoghq. Remove the stale DataDog copy and re-run:
  rm -rf "$dst"

EOF
            exit 1
        else
            ln -sfn "$src" "$dst"
            echo "  Linked $name -> ddoghq"
        fi
    done
}

# GitHub auth + keys for both accounts (tausman and the tausif-rahman_ddog managed
# identity). Generates a per-machine keypair for each account, uploads the public
# halves (auth for both, signing for tausman), records signing trust, and walks
# through SSO authorization. Runs standalone (`install.sh auth`) so it works the
# same on the laptop and the workspace. Idempotent — existing keys, uploads, and
# scopes are detected and skipped. Private keys never leave the machine.
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

    # Both accounts must be logged in: the primary (tausman) and the Datadog
    # managed identity (tausif-rahman_ddog). gh auth login picks up whichever
    # account you authenticate as in the browser, so verify each by name and only
    # run the flow for a missing one. -w opens a browser, -c copies the code.
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

    # Per-account on-disk SSH keys. Git normally rides the forwarded agent (keys
    # live on the laptop), which dies when the laptop sleeps. So each account also
    # gets its own keypair on this machine: github.com authenticates as tausman and
    # ddoghq.github.com as tausif-rahman_ddog (see custom/github-keys.config, which
    # appends these as fallback identities). tausman's key additionally signs
    # commits. All helpers below act on the currently-active gh account.
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
        # Smart: skip entirely if the key already works. Interactive otherwise —
        # point at the authorize page, wait for Enter, re-verify in a loop. SAML
        # SSO for a new SSH key cannot be granted from the CLI.
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

    # The signing key lives on tausman only: GitHub rejects the same SSH key on a
    # second account ("key is already in use"), so it can't be shared with the ddog
    # account. That's fine — every commit is signed with the tausman key, and
    # GitHub verifies against whichever account holds the commit's verified email
    # (tausif.rahman@datadoghq.com is on tausman, which also has DataDog org access).

    # Trust the signing key locally so jj/git can verify our own commits.
    mkdir -p ~/.ssh
    grep -qF "$(cat ~/.ssh/id_ed25519_tausman.pub)" ~/.ssh/allowed_signers 2>/dev/null || \
        echo "tausif.rahman@datadoghq.com $(cat ~/.ssh/id_ed25519_tausman.pub)" >> ~/.ssh/allowed_signers

    # Leave the Datadog managed identity active for the rest of the flow.
    gh auth switch -h github.com -u tausif-rahman_ddog
    echo "gh accounts + keys OK."
}

init() {
    echo "initializing..."

    # --- prechecks: bail before doing any work if prerequisites are missing ---
    # git-config-tool export must have been run from the laptop. The export
    # copies ~/.config/datadog/git/ here and wires the gitconfig include +
    # ssh_config Include that route ddoghq-sandbox clones (e.g. the pi packages
    # in setup_pi) through the tausif-rahman_ddog managed identity. Without it
    # those clones fail with "Repository not found".
    local cfg_dir="$HOME/.config/datadog/git"
    local ok=1
    # Config files must be present on disk...
    { [ -f "$cfg_dir/ssh_config" ] && grep -q 'ddoghq.github.com' "$cfg_dir/ssh_config"; } || ok=0
    { [ -f "$cfg_dir/config" ]     && grep -q 'ddoghq-sandbox'    "$cfg_dir/config";     } || ok=0
    # ...AND actually wired in (include resolves, ssh alias maps to the ghkey).
    git config --get-regexp 'url\.git@ddoghq\.github\.com.*\.insteadof' >/dev/null 2>&1 || ok=0
    ssh -G ddoghq.github.com 2>/dev/null | grep -qi 'identityfile.*ghkey' || ok=0
    if [ "$ok" -ne 1 ]; then
        cat >&2 <<EOF

ERROR: git-config-tool export has not been run for this workspace.
ddoghq-sandbox clones (e.g. datadog-pi-packages) will fail without it.

Run this FROM YOUR LAPTOP, then re-run install.sh:

    git config-tool export workspace-$(hostname -s 2>/dev/null || hostname)

EOF
        exit 1
    fi
    echo "git-config-tool export OK."

    # gh is preinstalled on the workspace — upgrade the system package in place
    # rather than installing a separate brew-managed gh.
    if ! command -v gh >/dev/null 2>&1; then
        echo "ERROR: gh not found on this system (expected it to be preinstalled)." >&2
        exit 1
    fi
    sudo apt-get install -y --only-upgrade gh >/dev/null 2>&1 || true

    # GitHub accounts, per-account SSH keys, commit-signing key, and SSO — all in
    # the standalone auth step so it can also be run on its own (`install.sh auth`).
    setup_auth
    # --- end prechecks ---

    # Make repos that migrated to the ddoghq org resolve at their old DataDog
    # paths (and under ~/dd). Runs after gh login so auth is already sorted.
    link_ddoghq_repos

    # jj/git sign commits (signing.behavior="own") with ~/.ssh/id_ed25519_tausman.pub,
    # which is generated and uploaded (auth + signing) in the per-account key setup
    # above — so no key needs to be pulled from the forwarded agent anymore.

    # Install linuxbrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Activate brew for the rest of this script run (it isn't on PATH yet, and
    # this bash process never sources ~/.zshenv where the persistent setup lives).
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"

    # gh install + account login is handled in the prechecks at the top of init.
    echo "init complete"
    echo "Run: source ~/.zshrc"
}

setup_base() {
    echo "Setting up base tools..."

    # Keep ddtool (workspace-managed Datadog CLI) current. Guarded so it no-ops
    # off-workspace (e.g. the laptop) and a failed update doesn't abort the run.
    if command -v update-tool >/dev/null 2>&1; then
        update-tool ddtool || echo "  update-tool ddtool failed (continuing)"
    fi

    # core tools
    # Keep tmux as the distro-managed package instead of swapping in a brew one.
    # Installing a brew tmux while attached to a running (apt) tmux server breaks:
    # the new client can't talk to the old server (protocol version mismatch), and
    # TPM's install_plugins shells out to tmux against that server. apt install
    # (no remove) leaves the running server's binary path stable, so no mismatch.
    sudo apt install -y tmux
    # tree-sitter-cli: required by nvim-treesitter (main branch) to compile
    # language parsers from source. The npm/cargo routes don't work on the
    # workspace (prebuilt binary needs a newer glibc; cargo build needs
    # libclang), but the brew bottle links against linuxbrew's own glibc.
    brew install neovim fzf go jj ripgrep nnn jjui tree-sitter-cli
    brew tap datadog-labs/pack
    brew install datadog-labs/pack/pup
    curl -Ls https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs | sh
    if [ ! -d ~/.tmux/plugins/tpm ]; then
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    fi
    # Install TPM plugins headlessly. TPM reads TMUX_PLUGIN_MANAGER_PATH from the
    # tmux server, but `tmux start-server` (which TPM calls) does NOT source the
    # config, and a server already running (e.g. if install.sh runs inside tmux)
    # won't have it set. So set it explicitly on the server before installing.
    tmux start-server
    tmux set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.tmux/plugins/"
    ~/.tmux/plugins/tpm/bin/install_plugins

    # go tools
    go install github.com/golang/mock/mockgen@v1.6.0

    # rust install
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # obsidian
    mkdir -p ~/vaults/work

    # Colocate jj in the dotfiles repo itself (skip if already initialized —
    # jj errors on re-init).
    if [ ! -d "$DOTFILES_DIR/.jj" ]; then
        cd "$DOTFILES_DIR"
        jj git init --colocate
    fi

    echo "Base setup complete."
    echo "Run: source ~/.zshrc"
}

# Volta-managed node/npm, needed by both setup_pi (global npm install) and
# setup_web_ui (pinned node). Idempotent and order-independent — safe to call
# from either. Exports persist to later steps in the same `all` run, and make
# standalone `./install.sh pi` / `web-ui` work too.
setup_node() {
    brew install volta
    export VOLTA_HOME="$HOME/.volta"
    export PATH="$VOLTA_HOME/bin:$PATH"
    # Ensure a default node/npm exists; web-ui pins its own version separately.
    command -v node >/dev/null 2>&1 || volta install node
}

setup_web_ui() {
    echo "Setting up web-ui development environment..."
    cd ~/dd/web-ui

    setup_node

    # Install the Node version web-ui pins (.node-version / package.json "volta").
    # Without this, volta falls back to an older default Node that's too old for
    # web-ui's tooling (oxfmt needs the pinned 24.x to load its .ts config).
    volta install "node@$(cat .node-version)"

    # Install Yarn Switch (per-project yarn version manager)
    curl -sS https://repo.yarnpkg.com/install | bash
    export PATH="$HOME/.yarn/switch/bin:$PATH"

    # Drop volta's yarn shims first so yarn-switch's yarn wins on PATH.
    rm -f ~/.volta/bin/yarn ~/.volta/bin/yarnpkg

    # Install web-ui deps (large monorepo, multi-GB). Retry to ride out flaky
    # registry fetches like "Network error: error decoding response body".
    local attempt ok=0
    for attempt in 1 2 3; do
        if yarn install; then ok=1; break; fi
        echo "yarn install failed (attempt $attempt/3), retrying in 5s..."
        sleep 5
    done
    [ "$ok" -eq 1 ] || { echo "yarn install failed after 3 attempts" >&2; exit 1; }

    bash ./dev/ssl/generate_and_trust_localhost_certificate.sh
    brew install watchman

    git config remote.origin.tagOpt --no-tags
    git config remote.origin.prune true

    # Run doctor and apply fixes
    bash doctor

    echo "Web UI setup complete."
    cat <<'EOF'
    DONT FORGET TO RUN:
    scp workspace-${name}:~/.config/datadog/dev-ssl/localhost.crt ~
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/localhost.crt
EOF
    echo "Run: source ~/.zshrc"
}

# Repos setup_repos knows how to configure (basenames under ~/dd). Also the set of
# valid values for the optional single-repo argument.
REPOS=(dd-source dd-go dogweb web-ui team-aaa-internal-tools datadog-pi-packages)

# Abort unless $1 is empty (meaning all repos) or a known repo basename.
validate_repo() {
    [ -z "$1" ] && return 0
    printf '%s\n' "${REPOS[@]}" | grep -qxF "$1" || {
        echo "ERROR: unknown repo '$1'. Valid: ${REPOS[*]}" >&2
        exit 1
    }
}

# setup_repos [repo]: configure fetch refs + colocate jj for the dd/* repos. With
# an optional <repo> basename (e.g. dd-source) only that one is cloned/configured —
# a fast path when you just need a single repo ready.
setup_repos() {
    local only="$1"
    validate_repo "$only"
    if [ -n "$only" ]; then
        echo "Setting up repo fetch config for '$only' only..."
    else
        echo "Setting up repo fetch configs..."
    fi

    # Clone repos that aren't checked out by other tooling. The dd/* monorepos
    # are expected to already exist; these we fetch ourselves. Skipped when a
    # different single repo was requested.
    if [ -z "$only" ] || [ "$only" = team-aaa-internal-tools ]; then
        [ -d ~/dd/team-aaa-internal-tools/.git ] || \
            git clone git@github.com:DataDog/team-aaa-internal-tools.git ~/dd/team-aaa-internal-tools
        # Expose the acepg postgres-access helper (a git-tracked bash script) on
        # PATH, mirroring the local ~/.local/bin/acepg symlink.
        mkdir -p ~/.local/bin
        ln -sf ~/dd/team-aaa-internal-tools/postgres-access-tool/acepg ~/.local/bin/acepg
    fi

    # pi coding agent packages — lives in the ddoghq-sandbox org, accessed via the
    # tausif-rahman_ddog managed identity.
    if [ -z "$only" ] || [ "$only" = datadog-pi-packages ]; then
        [ -d ~/dd/datadog-pi-packages/.git ] || \
            git clone git@github.com:ddoghq-sandbox/datadog-pi-packages.git ~/dd/datadog-pi-packages
    fi

    local repos=(~/dd/dd-source ~/dd/dd-go ~/dd/dogweb ~/dd/web-ui ~/dd/team-aaa-internal-tools ~/dd/datadog-pi-packages)

    for repo in "${repos[@]}"; do
        if [ -n "$only" ] && [ "$(basename "$repo")" != "$only" ]; then
            continue
        fi
        if [ ! -d "$repo/.git" ]; then
            echo "Skipping $repo (not a git repo)"
            continue
        fi

        echo "Configuring $repo..."
        cd "$repo"

        # Detect default branch from remote
        local default_branch
        default_branch=$(git ls-remote --symref origin HEAD | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2}')

        if [ -z "$default_branch" ]; then
            echo "  Could not determine default branch, skipping"
            continue
        fi
        echo "  Default branch: $default_branch"

        # Remove all existing remote tracking refs
        git symbolic-ref --delete refs/remotes/origin/HEAD 2>/dev/null || true
        git for-each-ref --format='delete %(refname)' refs/remotes/origin/ | git update-ref --stdin 2>/dev/null || true

        # Configure fetch to only track default branch and tausman/* branches.
        # Clear any existing values first so this is safe to re-run (the key is
        # multi-valued, so a plain `git config` set would fail on later runs).
        git config --unset-all remote.origin.fetch 2>/dev/null || true
        git config --add remote.origin.fetch "+refs/heads/${default_branch}:refs/remotes/origin/${default_branch}"
        git config --add remote.origin.fetch '+refs/heads/tausman*:refs/remotes/origin/tausman*'

        # Fetch configured refs
        git fetch origin

        # Colocate jj (skip if already initialized — jj errors on re-init)
        if [ ! -d .jj ]; then
            jj git init --colocate
        fi

        echo "  Done."
    done
    echo "Repo setup complete."
}

setup_claude() {
    echo "Setting up Claude..."
    claude install
    # Skills, agents, commands, and MCP servers live in the standalone "tausman"
    # marketplace repo (github.com/tausman/claude-plugins), split out of dotfiles.
    # Keep a local clone at ~/claude-plugins purely for editing; the marketplace
    # is sourced from the remote so `claude plugin marketplace update tausman` can
    # pull changes directly. See that repo's README for the propagation workflow.
    local plugins_repo="git@github.com:tausman/claude-plugins.git"
    local plugins_dir="$HOME/claude-plugins"
    [ -d "$plugins_dir/.git" ] || git clone "$plugins_repo" "$plugins_dir"
    # Colocate jj in the editing clone (skip if already initialized — jj errors
    # on re-init).
    if [ ! -d "$plugins_dir/.jj" ]; then
        ( cd "$plugins_dir" && jj git init --colocate )
    fi
    # Both commands exit non-zero if already present, which would abort under
    # `set -e`, so guard each on a presence check.
    claude plugin marketplace list 2>/dev/null | grep -q '\btausman\b' || \
        claude plugin marketplace add "$plugins_repo"
    claude plugin list 2>/dev/null | grep -q 'tausman@tausman' || \
        claude plugin install tausman@tausman
    echo "Claude setup complete."
}

setup_pi() {
    echo "Setting up pi..."
    setup_node
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent
    echo "pi setup complete."
}

setup_dogweb() {
    echo "Setting up dogweb..."
    cd ~/dd/dogweb

    # Bring up dogweb's local service dependencies (databases, etc.) before
    # update_deps wires everything together. `-d --wait` starts the stack in the
    # background but blocks until the containers are healthy, so update_deps only
    # runs once they're up.
    #
    # `dd-compose` is an interactive shell alias (see /etc/profile.d/00-workspace-env.sh)
    # that isn't available in this non-interactive script, so point docker-compose
    # directly at the workspace compose file shipped in dd-source.
    docker-compose -f "$HOME/dd/dd-source/domains/devex/workspaces/apps/shell-image/etc/container-config/compose.yaml" up -d --wait

    update_deps
    # This doesn't work in the script
    # pytest dogweb/tests/unit/util/test_signup.py
    alias py3test='/opt/dogweb/bin/python -m pytest --showlocals'
    echo "Dogweb setup complete."
}

# run_all [repo]: full install. With an optional <repo>, setup_repos handles only
# that repo and the heavy web-ui/dogweb steps run only when they're the target —
# a much faster path when you just need one repo ready.
run_all() {
    local only="$1"
    validate_repo "$only"   # fail fast, before the long install
    init
    move_originals
    stow_packages
    setup_base
    setup_repos "$only"
    setup_claude
    setup_pi
    if [ -z "$only" ] || [ "$only" = web-ui ]; then
        setup_web_ui
    fi
    if [ -z "$only" ] || [ "$only" = dogweb ]; then
        setup_dogweb
    fi
    echo "Run: source ~/.zshrc"
    cat <<'EOF'
    DONT FORGET TO RUN ON THE HOST:
    scp workspace-${name}:~/.config/datadog/dev-ssl/localhost.crt ~
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/localhost.crt
EOF
}

case "${1:-stow}" in
    all)            run_all "$2" ;;
    init)           init ;;
    auth)           setup_auth ;;
    move-originals) move_originals ;;
    stow)           stow_packages ;;
    base)           setup_base ;;
    repos)          setup_repos "$2" ;;
    web-ui)         setup_web_ui ;;
    claude)         setup_claude ;;
    pi)             setup_pi ;;
    dogweb)         setup_dogweb ;;
    *)              echo "Usage: $0 {all [repo]|init|auth|move-originals|stow|base|repos [repo]|web-ui|claude|pi|dogweb}" && exit 1 ;;
esac
