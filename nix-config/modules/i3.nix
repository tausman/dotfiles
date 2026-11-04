{ pkgs, liveLink, ... }:
{
  # One complete live config for native Linux and Ubuntu/VNC.
  home.file.".config/i3/config".source = liveLink "config/.config/i3/config";
  home.file.".config/i3/toggle_theme.sh".source = liveLink "config/.config/i3/toggle_theme.sh";
  home.file.".Xresources".source = liveLink "config/.config/i3/.Xresources";

  # i3 blocks config
  home.file.".config/i3blocks/config".source = liveLink "config/.config/i3blocks/config";

  home.packages = with pkgs; [
    xdg-desktop-portal-gtk
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };
}
