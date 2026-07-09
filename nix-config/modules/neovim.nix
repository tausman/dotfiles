{ pkgs, liveLink, ... }:
{
  home.packages = [ pkgs.neovim ];

  # Neovim — lazy.nvim writes lazy-lock.json into the config dir, so it's a live symlink.
  # Language toolchains nvim needs at runtime (go, nodejs, tree-sitter, cmake) live in
  # dev.nix.
  home.file.".config/nvim".source = liveLink "config/.config/nvim";
}
