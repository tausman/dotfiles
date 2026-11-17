{ config, lib, pkgs, ... }:
let
  cfg = config.dogbrew;
  user = config.system.primaryUser;
  sync = pkgs.writeShellApplication {
    name = "dogbrew-sync";
    text = ''
      exec ${pkgs.bash}/bin/bash ${../scripts/dogbrew-sync.sh} \
        /opt/dogbrew ${lib.escapeShellArgs cfg.packages}
    '';
  };
in
{
  options.dogbrew = {
    enable = lib.mkEnableOption "installation of declared internal CLIs with Dogbrew";
    packages = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[a-zA-Z0-9][a-zA-Z0-9._+-]*");
      default = [];
      description = ''
        Dogbrew CLI names to install on every activation using dogbrew install,
        which selects the latest allowed release. Dogbrew must already be
        bootstrapped and reachable. Removing a name does not uninstall it.
        These installations are not rolled back by Nix.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    system.requiresPrimaryUser = [ "dogbrew.enable" ];
    environment.systemPackages = [ sync ];

    # System activation is root, but Dogbrew's prefix and Workspaces launch agent
    # belong to the user. Preserve the user's launchd context for install hooks.
    # mkAfter keeps darwin.nix's existing wallpaper/account activation intact.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo >&2 "Installing/updating Dogbrew packages..."
      /bin/launchctl asuser "$(/usr/bin/id -u ${lib.escapeShellArg user})" \
        /usr/bin/sudo --user=${lib.escapeShellArg user} --set-home \
        ${lib.getExe sync} || exit 1
    '';
  };
}
