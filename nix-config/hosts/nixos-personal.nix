{ lib, ... }:
{
  imports = [ ../profiles/linux-desktop.nix ];

  home.username = "t";
  home.homeDirectory = "/home/t";

  _module.args = {
    profileName = lib.mkForce "personal";
  };
}
