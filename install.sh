#!/usr/bin/env bash
# Run order: init -> move_originals -> stow -> base -> repos -> web-ui -> dogweb
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

PACKAGES=(
    claude
    config
    git
    jj
    scripts
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
        if [ "$pkg" = "jj" ]; then
            stow -R -d "$DOTFILES_DIR" -t "$HOME" --dotfiles --no-folding "$pkg"
        else
            stow -R -d "$DOTFILES_DIR" -t "$HOME" --dotfiles "$pkg"
        fi
    done
    echo "Done stowing packages."
    echo "Run: source ~/.zshrc"
}

init() {
    echo "initializing..."
    # Install linuxbrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo >> ~/.zshenv
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"' >> ~/.zshenv
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
    curl -Ls https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs | sh
    # Symlink tmux into ~/.local/bin so tmux's run-shell subprocesses can find it
    # (they inherit tmux's global PATH, which doesn't include the Linuxbrew prefix)
    ln -sf /home/linuxbrew/.linuxbrew/bin/tmux ~/.local/bin/tmux
    if [ ! -d ~/.tmux/plugins/tpm ]; then
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    fi
    # Install TPM plugins headlessly
    tmux new-session -d -s tpm_install 2>/dev/null || true
    ~/.tmux/plugins/tpm/bin/install_plugins
    tmux kill-session -t tpm_install 2>/dev/null || true

    # go tools
    go install github.com/golang/mock/mockgen@v1.6.0

    # rust install
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

    # obsidian
    mkdir -p ~/vaults/work

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
    local repos=(~/dd/dd-source ~/dd/dd-go ~/dd/dogweb ~/dd/web-ui)

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

        # Configure fetch to only track default branch and tausman/* branches
        git config remote.origin.fetch "+refs/heads/${default_branch}:refs/remotes/origin/${default_branch}"
        git config --add remote.origin.fetch '+refs/heads/tausman*:refs/remotes/origin/tausman*'

        # Fetch configured refs
        git fetch origin

        # Colocate jj
        jj git init --colocate

        echo "  Done."
    done
    echo "Repo setup complete."
}

setup_claude() {
    echo "Setting up Claude..."
    claude install
    claude mcp add --scope user --transport sse atlassian https://mcp.atlassian.com/v1/sse
    claude mcp add --scope user --transport http datadog-mcp https://mcp.datadoghq.com/api/unstable/mcp-server/mcp
    echo "Claude setup complete."
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
    dogweb)         setup_dogweb ;;
    *)              echo "Usage: $0 {all|init|move-originals|stow|base|repos|web-ui|claude|dogweb}" && exit 1 ;;
esac
