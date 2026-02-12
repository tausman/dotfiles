#!/usr/bin/env bash
# Run order: move_originals -> stow -> base -> web-ui -> dogweb
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
    sudo apt install stow
    cd ~/dotfiles
    for pkg in "${PACKAGES[@]}"; do
        echo "Stowing $pkg..."
        stow -d "$DOTFILES_DIR" -t "$HOME" --dotfiles "$pkg"
    done
    echo "Done stowing packages."
    cd ~
}

setup_base() {
    echo "Setting up base tools..."

    # Install linuxbrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo >> /home/bits/.zshrc
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"' >> /home/bits/.zshrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"

    brew install gh neovim

    gh auth login
    echo "tausif.rahman@datadoghq.com $(cat ~/.ssh/id_ed25519.pub)" > ~/.ssh/allowed_signers

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

    sudo apt remove tmux
    brew install tmux

    echo "Base setup complete."
    echo "BE SURE TO ADD YOUR SIGNING KEY TO YOUR PROFILE: `~/.ssh/id_ed25519.pub`"
    cd ~
}

setup_web_ui() {
    echo "Setting up web-ui development environment..."
    cd ~/dd/web-ui

    # Install volta
    curl https://get.volta.sh | bash

    # Install yarn switch
    curl -sS https://repo.yarnpkg.com/install | bash
    rm ~/.volta/bin/yarn ~/.volta/bin/yarnpkg

    source ~/.zshrc
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
    cd ~
}

setup_dogweb() {
    echo "Setting up dogweb..."
    cd ~/dd/dogweb
    update_deps
    pytest dogweb/tests/unit/util/test_signup.py
    alias py3test='/opt/dogweb/bin/python -m pytest --showlocals'
    echo "Dogweb setup complete."
    cd ~
}

run_all() {
    move_originals
    stow_packages
    setup_base
    setup_web_ui
    setup_dogweb
}

case "${1:-stow}" in
    all)            run_all ;;
    move-originals) move_originals ;;
    stow)           stow_packages ;;
    base)           setup_base ;;
    web-ui)         setup_web_ui ;;
    dogweb)         setup_dogweb ;;
    *)              echo "Usage: $0 {all|move-originals|stow|base|web-ui|dogweb}" && exit 1 ;;
esac
