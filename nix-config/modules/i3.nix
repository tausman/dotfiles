{ liveLink, ... }:
{
  # One complete live config for native Linux and Ubuntu/VNC.
  home.file.".config/i3/config".source = liveLink "config/.config/i3/config";
  home.file.".Xresources".source = liveLink "config/.config/i3/.Xresources";
}
