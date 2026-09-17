{ ... }:
{
  # A machine with no display (the Ubuntu VM): the shared bundle plus the Linux-only
  # extras. Every Linux host imports this (directly, or via ./remote-desktop.nix), so
  # it's where ./linux.nix hangs off — the same way ./desktop.nix pulls in ./darwin.nix.
  imports = [ ./base.nix ./linux.nix ];
}
