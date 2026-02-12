#!/usr/bin/env bash
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

stow_packages() {
    for pkg in "${PACKAGES[@]}"; do
        echo "Stowing $pkg..."
        stow -d "$DOTFILES_DIR" -t "$HOME" --dotfiles "$pkg"
    done
    echo "Done stowing packages."
}

setup_web_ui() {
    echo "Setting up web-ui development environment..."

    # Install volta
    curl https://get.volta.sh | bash

    # Install yarn switch
    curl -sS https://repo.yarnpkg.com/install | bash
    rm ~/.volta/bin/yarn ~/.volta/bin/yarnpkg

    # Run doctor and apply fixes
    bash doctor

    # Install linuxbrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
    test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc

    # Install watchman
    brew install watchman

    echo "Web UI setup complete."
}

case "${1:-stow}" in
    stow)    stow_packages ;;
    web-ui)  setup_web_ui ;;
    *)       echo "Usage: $0 {stow|web-ui}" && exit 1 ;;
esac
