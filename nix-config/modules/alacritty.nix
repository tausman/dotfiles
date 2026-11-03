{ pkgs, liveLink, config, ... }:
{
  # Shared settings/themes and their font, not the Alacritty application.
  # darwin.nix installs the app through Homebrew; linux-desktop.nix installs pkgs.alacritty.
  home.packages = [ pkgs.nerd-fonts.hack ]; # Alacritty's "Hack Nerd Font Mono"

  home.file.".config/alacritty/alacritty.toml".source = liveLink "config/.config/alacritty/alacritty.toml";
  home.file.".config/alacritty/my_themes/light.toml".source = liveLink "config/.config/alacritty/themes/themes/tausif_light_theme_soft.toml";
  home.file.".config/alacritty/my_themes/dark.toml".source = liveLink "config/.config/alacritty/themes/themes/github_dark_high_contrast_hard.toml";
  home.file.".config/alacritty/active_theme.toml".source =
  config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/alacritty/my_themes/light.toml";
}
