# This has some nixos specifc setup for local desktop
# Could be ported to other setups in the future.
{pkgs, ... }:
let
  volumeWatcher = pkgs.writeShellScript "pipewire-volume-watcher" ''
    set -o pipefail

    ${pkgs.pipewire}/bin/pw-dump --monitor |
      ${pkgs.jq}/bin/jq --unbuffered -c \
        'select(any(.[]?; .type == "PipeWire:Interface:Node"))' |
      while IFS= read -r _; do
        ${pkgs.procps}/bin/pkill -RTMIN+10 -x i3blocks || true
      done
  '';
in
{
  systemd.user.services.pipewire-volume-watcher = {
    Unit = {
      Description = "Watch Pipewire changes and refresh the i3blocks volume";
    };

    Service = {
      Type = "simple";
      ExecStart = "${volumeWatcher}";
      Restart = "always";
      RestartSec = 2;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
