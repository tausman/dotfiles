{ ... }:
{
  imports = [ ../profiles/remote-desktop.nix ];

  home.username = "t";
  home.homeDirectory = "/home/t";
}
