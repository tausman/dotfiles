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

for pkg in "${PACKAGES[@]}"; do
    echo "Stowing $pkg..."
    stow -d "$DOTFILES_DIR" -t "$HOME" --dotfiles "$pkg"
done

echo "Done."
