{ pkgs, flake }:
let
  inherit (pkgs) lib;
  system = flake.darwinConfigurations.default.config;
  home = flake.homeConfigurations.default.config;
  brewNames = map (entry: lib.removePrefix "datadog/tap/" entry.name)
    (system.homebrew.brews ++ system.homebrew.casks);
  activation = system.system.activationScripts.postActivation.text;
  tests = {
    enabled = system.dogbrew.enable;
    workspacesRenamed = builtins.elem "workspaces" system.dogbrew.packages
      && !(builtins.elem "datadog-workspaces" brewNames);
    noDuplicateManagers = lib.intersectLists system.dogbrew.packages brewNames == [];
    goplsStillOnBrew = builtins.elem "dd-gopls" brewNames;
    blockedReleaseStillOnBrew = builtins.elem "latest-datacenter-config" brewNames;
    nonDestructiveCleanup = system.homebrew.onActivation.cleanup == "none";
    userActivation = lib.hasInfix "/bin/launchctl asuser" activation
      && lib.hasInfix "--user=${lib.escapeShellArg system.system.primaryUser} --set-home" activation;
    existingActivationPreserved = lib.hasInfix "/usr/bin/osascript" activation;
    shellSetup = lib.hasInfix "/opt/dogbrew/share/etc/dogbrew/init.zsh" home.programs.zsh.profileExtra
      && lib.hasInfix "/opt/dogbrew/share/etc/dogbrew/init.zsh" home.programs.zsh.initContent;
  };
  failed = builtins.filter (name: !tests.${name}) (builtins.attrNames tests);
in
assert lib.assertMsg (failed == []) "Failed Dogbrew checks: ${lib.concatStringsSep ", " failed}";
pkgs.runCommand "dogbrew-check" {
  nativeBuildInputs = [ pkgs.bash pkgs.python3 pkgs.shellcheck pkgs.zsh ];
  preferLocalBuild = true;
  allowSubstitutes = false;
} ''
  shellcheck ${../scripts/dogbrew-sync.sh}
  python3 ${./dogbrew-sync.py} ${../scripts/dogbrew-sync.sh}
  zsh -n ${../../zshrc/.zshenv}
  zsh -n ${../../zshrc/.zshrc}
  touch "$out"
''
