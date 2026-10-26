{ ... }:
{
  # The shared Linux desktop, plus a virtual display reached over SSH/VNC.
  imports = [ ./linux-desktop.nix ../modules/vnc.nix ];
}
