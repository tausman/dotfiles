{ liveLink, ... }:
{
  # kmonad keyboard config, read by the launchd daemon defined in darwin.nix. The daemon
  # is macOS-only, so this link is imported only by the mac host.
  home.file.".config/kmonad.kbd".source = liveLink "kmonad/kmonad.kbd";
}
