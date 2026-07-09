{ pkgs, liveLink, ... }:
{
  # Alacritty itself is installed as a GUI app via darwin.nix; this module links its
  # config + themes and supplies the font it references. Imported only by hosts that
  # have a display (currently just the mac).
  home.packages = [ pkgs.nerd-fonts.hack ]; # Alacritty's "Hack Nerd Font Mono"

  home.file.".config/alacritty".source = liveLink "config/.config/alacritty";
}
