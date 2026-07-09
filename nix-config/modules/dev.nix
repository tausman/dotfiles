{ pkgs, ... }:
{
  # Language toolchains used across editors/projects.
  home.packages = with pkgs; [
    # Rust toolchain (nix-managed — cargo/rustc land on PATH directly, so there's no
    # rustup-style ~/.cargo/env; the zshrc sources that file only if it exists).
    rustc
    cargo
    clippy
    rustfmt
    rust-analyzer
    # Build tool for compiling native nvim plugins (e.g. telescope-fzf-native).
    cmake
    # Toolchains mason.nvim needs to install LSP servers:
    #   go  → gopls;  nodejs (npm) → pyright, vtsls, yaml/eslint/vim language servers.
    go
    nodejs
    # tree-sitter CLI — nvim-treesitter (main branch) uses it to generate/compile parsers.
    tree-sitter
  ];
}
