{ pkgs, ... }:
{
  # Linux-only extras — the mirror of ./darwin.nix on the other platform axis. Every
  # entry here is something nixpkgs only builds for Linux (or that only makes sense
  # against a Linux kernel), so it can't live in modules/core.nix without an
  # `optionals isLinux` guard at each use site. Imported by ./headless.nix, which is
  # the root of every Linux host's import chain.
  #   keyutils — keyctl/request-key, the kernel keyring CLI. nixpkgs marks it
  #              linux-only, so it fails the platform check on the mac.
  home.packages = with pkgs; [
    keyutils
  ];
}
