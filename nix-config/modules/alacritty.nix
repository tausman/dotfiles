{ pkgs, liveLink, ... }:
{
  # Shared settings/themes and their font, not the Alacritty application.
  # darwin.nix installs the app through Homebrew; linux-desktop.nix installs pkgs.alacritty.
  home.packages = [ pkgs.nerd-fonts.hack ]; # Alacritty's "Hack Nerd Font Mono"

  home.file.".config/alacritty".source = liveLink "config/.config/alacritty";
}
