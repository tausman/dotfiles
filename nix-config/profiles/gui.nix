{ ... }:
{
  # Extras for a machine with a display (currently just the mac).
  #   alacritty — GUI terminal (role/GUI-axis).
  #   kmonad    — keyboard remap; strictly Darwin-axis (its launchd daemon lives in
  #               darwin.nix), but co-located here for now since the only GUI host is
  #               also the only Mac. Split into a profiles/darwin.nix if a Linux desktop
  #               ever appears.
  imports = [
    ../modules/alacritty.nix
    ../modules/kmonad.nix
  ];
}
