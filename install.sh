#!/usr/bin/env bash
# Run order: init -> move_originals -> stow -> base -> web-ui -> dogweb
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

PACKAGES=(
    claude
    config
    git
    scripts
    tmux
    zshrc
)

move_originals() {
    echo "Moving original files..."
    [ -f ~/.zshrc ] && mv ~/.zshrc ~/.zshrc_original
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
        stow -R -d "$DOTFILES_DIR" -t "$HOME" --dotfiles "$pkg"
    done
    echo "Done stowing packages."
    echo "Run: source ~/.zshrc"
}

init() {
    echo "initializing..."
    # Install linuxbrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo >> ~/.zshrc
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"' >> ~/.zshrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"

    # github config
    brew install gh
    if ! gh auth status &>/dev/null; then
        gh auth login
        echo "tausif.rahman@datadoghq.com $(cat ~/.ssh/id_ed25519.pub)" > ~/.ssh/allowed_signers
        gh ssh-key add ~/.ssh/id_ed25519.pub --type signing
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
    brew install neovim fzf tmux go

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

    # Install yarn switch
    curl -sS https://repo.yarnpkg.com/install | bash
    export PATH="$HOME/.yarn/switch/bin:$PATH"

    yarn
    yarn install
    yarn dev

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

setup_dogweb() {
    echo "Setting up dogweb..."
    cd ~/dd/dogweb
    update_deps
    pytest dogweb/tests/unit/util/test_signup.py
    alias py3test='/opt/dogweb/bin/python -m pytest --showlocals'
    echo "Dogweb setup complete."
}

run_all() {
    init
    move_originals
    stow_packages
    setup_base
    setup_web_ui
    setup_dogweb
    echo "BE SURE TO ADD YOUR SIGNING KEY TO YOUR PROFILE ON GITHUB: `~/.ssh/id_ed25519.pub`"
}

case "${1:-stow}" in
    all)            run_all ;;
    init)           init ;;
    move-originals) move_originals ;;
    stow)           stow_packages ;;
    base)           setup_base ;;
    web-ui)         setup_web_ui ;;
    dogweb)         setup_dogweb ;;
    *)              echo "Usage: $0 {all|init|move-originals|stow|base|web-ui|dogweb}" && exit 1 ;;
esac
