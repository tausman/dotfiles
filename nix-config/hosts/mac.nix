{ ... }:
{
  # macOS laptop — a desktop (GUI) machine. Homebrew's shellenv is handled in
  # modules/zsh.nix (guarded on isDarwin), so nothing platform-specific is needed here.
  imports = [ ../profiles/desktop.nix ];

  home.username = "tausif.rahman";
  home.homeDirectory = "/Users/tausif.rahman";
}
