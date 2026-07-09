{ ... }:
{
  # A machine with a display: the shared bundle plus the GUI extras.
  imports = [ ./base.nix ./gui.nix ];
}
