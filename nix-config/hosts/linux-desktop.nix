{ ... }:
{
  # The same Ubuntu VM as ./linux.nix, but running the VNC remote desktop. Identity is
  # repeated rather than shared: hosts are meant to be a flat "identity + one profile",
  # and an extra indirection to save two lines would cost more than it saves.
  imports = [ ../profiles/remote-desktop.nix ];

  home.username = "bits";
  home.homeDirectory = "/home/bits";
}
