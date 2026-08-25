{ ... }:
{
  # The mac: the shared bundle plus the macOS-only extras.
  imports = [ ./base.nix ./darwin.nix ];
}
