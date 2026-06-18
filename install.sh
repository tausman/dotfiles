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
    echo "Done stowing packages."
    # Reload tmux config into any running server so changes take effect without
    # restarting tmux (no-op if no server is running).
    tmux source-file ~/.tmux.conf 2>/dev/null || true
    echo "Run: source ~/.zshrc"
}

init() {
    echo "initializing..."
    # Install linuxbrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Activate brew for the rest of this script run (it isn't on PATH yet, and
    # this bash process never sources ~/.zshenv where the persistent setup lives).
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"

    # github config
    brew install gh
    if ! gh auth status &>/dev/null; then
        gh auth login -h github.com -s admin:ssh_signing_key
        gh ssh-key add ~/.ssh/id_ed25519.pub --type signing
        echo "tausif.rahman@datadoghq.com $(cat ~/.ssh/id_ed25519.pub)" > ~/.ssh/allowed_signers
    else
        echo "gh already authenticated, skipping..."
    fi
    echo "init complete"
    echo "Run: source ~/.zshrc"
}

setup_base() {
    echo "Setting up base tools..."

    # core tools
    sudo apt remove -y tmux
    brew install neovim fzf tmux go jj ripgrep nnn jjui
    brew tap datadog-labs/pack
    brew install datadog-labs/pack/pup
    curl -Ls https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs | sh
    # Symlink tmux into ~/.local/bin so tmux's run-shell subprocesses can find it
    # (they inherit tmux's global PATH, which doesn't include the Linuxbrew prefix)
    ln -sf /home/linuxbrew/.linuxbrew/bin/tmux ~/.local/bin/tmux
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

setup_web_ui() {
    echo "Setting up web-ui development environment..."
    cd ~/dd/web-ui

    # Install volta
    brew install volta
    export VOLTA_HOME="$HOME/.volta"
    export PATH="$VOLTA_HOME/bin:$PATH"

    # Install the Node version web-ui pins (.node-version / package.json "volta").
    # Without this, volta falls back to an older default Node that's too old for
    # web-ui's tooling (oxfmt needs the pinned 24.x to load its .ts config).
    volta install "node@$(cat .node-version)"

    # Install yarn switch
    curl -sS https://repo.yarnpkg.com/install | bash
    export PATH="$HOME/.yarn/switch/bin:$PATH"

    yarn
    rm -f ~/.volta/bin/yarn ~/.volta/bin/yarnpkg
    yarn install

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

setup_repos() {
    echo "Setting up repo fetch configs..."

    # Clone repos that aren't checked out by other tooling. The dd/* monorepos
    # are expected to already exist; this one we fetch ourselves.
    [ -d ~/dd/team-aaa-internal-tools/.git ] || \
        git clone git@github.com:DataDog/team-aaa-internal-tools.git ~/dd/team-aaa-internal-tools

    # Expose the acepg postgres-access helper (a git-tracked bash script) on
    # PATH, mirroring the local ~/.local/bin/acepg symlink.
    mkdir -p ~/.local/bin
    ln -sf ~/dd/team-aaa-internal-tools/postgres-access-tool/acepg ~/.local/bin/acepg

    local repos=(~/dd/dd-source ~/dd/dd-go ~/dd/dogweb ~/dd/web-ui ~/dd/team-aaa-internal-tools)

    for repo in "${repos[@]}"; do
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
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent
    echo "pi setup complete."
}

setup_dogweb() {
    echo "Setting up dogweb..."
    cd ~/dd/dogweb
    update_deps
    # This doesn't work in the script
    # pytest dogweb/tests/unit/util/test_signup.py
    alias py3test='/opt/dogweb/bin/python -m pytest --showlocals'
    echo "Dogweb setup complete."
}

run_all() {
    init
    move_originals
    stow_packages
    setup_base
    setup_repos
    setup_claude
    setup_pi
    setup_web_ui
    setup_dogweb
    echo "Run: source ~/.zshrc"
    cat <<'EOF'
    DONT FORGET TO RUN ON THE HOST:
    scp workspace-${name}:~/.config/datadog/dev-ssl/localhost.crt ~
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/localhost.crt
EOF
}

case "${1:-stow}" in
    all)            run_all ;;
    init)           init ;;
    move-originals) move_originals ;;
    stow)           stow_packages ;;
    base)           setup_base ;;
    repos)          setup_repos ;;
    web-ui)         setup_web_ui ;;
    claude)         setup_claude ;;
    pi)             setup_pi ;;
    dogweb)         setup_dogweb ;;
    *)              echo "Usage: $0 {all|init|move-originals|stow|base|repos|web-ui|claude|pi|dogweb}" && exit 1 ;;
esac
