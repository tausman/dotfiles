{ pkgs, ... }:
{
  # Extras for a machine with a display (currently just the mac).
  #   alacritty — GUI terminal (role/GUI-axis).
  #   ghostty   — GUI terminal (role/GUI-axis); shares Alacritty's Hack Nerd Font.
  #   kmonad    — keyboard remap; strictly Darwin-axis (its launchd daemon lives in
  #               darwin.nix), but co-located here for now since the only GUI host is
  #               also the only Mac. Split into a profiles/darwin.nix if a Linux desktop
  #               ever appears.
  imports = [
    ../modules/alacritty.nix
    ../modules/ghostty.nix
    ../modules/kmonad.nix
  ];

  # GUI-only tools (not wanted on the headless workstation).
  #   ffmpeg — media transcoding; only useful in a non-headless context.
  home.packages = with pkgs; [
    ffmpeg
  ];
}
