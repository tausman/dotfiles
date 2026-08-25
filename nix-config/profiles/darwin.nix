{ pkgs, ... }:
{
  # macOS-only extras. This was profiles/gui.nix, but nothing in it is really about
  # *having a display* — every entry is Darwin-shaped: alacritty and ghostty are
  # installed as GUI apps by darwin.nix/Homebrew and these modules only link their
  # configs, and kmonad's launchd daemon is macOS-only. So the Linux remote desktop
  # (profiles/remote-desktop.nix) shares nothing with it and this is named for the
  # axis it actually tracks.
  #   alacritty — GUI terminal config + the Hack Nerd Font both terminals reference.
  #   ghostty   — GUI terminal config (font comes from the alacritty module).
  #   kmonad    — keyboard remap config, read by the launchd daemon in darwin.nix.
  imports = [
    ../modules/alacritty.nix
    ../modules/ghostty.nix
    ../modules/kmonad.nix
  ];

  # Mac-only tools.
  #   ffmpeg — media transcoding; only useful where there's a display to play to.
  home.packages = with pkgs; [
    ffmpeg
  ];
}
