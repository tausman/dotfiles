{ liveLink, ... }:
{
  # Ghostty itself is installed as a GUI app via Homebrew (casks in darwin.nix); this
  # module just links its config + themes. The font it references (Hack Nerd Font Mono)
  # is supplied by modules/alacritty.nix, which every GUI host imports alongside this.
  home.file.".config/ghostty".source = liveLink "config/.config/ghostty";
}
