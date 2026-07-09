{ ... }:
{
  # Headless Ubuntu VM (user: bits). Same file drives both arches; the flake picks the arch.
  imports = [ ../profiles/headless.nix ];

  home.username = "bits";
  home.homeDirectory = "/home/bits";
}
