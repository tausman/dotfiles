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
    # go → gopls for mason.nvim. (nodejs — used by the JS/TS-based LSP servers — lives in
    # modules/nodejs.nix.)
    go
    # mockgen — Go mock generator (install.sh got this via `go install .../mockgen`).
    mockgen
    # tree-sitter CLI — nvim-treesitter (main branch) uses it to generate/compile parsers.
    tree-sitter
    # python/ruby version managers. The dotfiles zshrc runs `pyenv init`/`rbenv init` when
    # present. On the mac the brew copies (darwin.nix) take PATH precedence and shadow these.
    pyenv
    rbenv
  ];
}
