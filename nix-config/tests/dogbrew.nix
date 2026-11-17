{ pkgs, flake }:
let
  inherit (pkgs) lib;
  system = flake.darwinConfigurations.default.config;
  homes = map (name: flake.homeConfigurations.${name}.config)
    [ "default" "ubuntu-aarch64" "ubuntu-x86_64" ];
  packages = import ../dogbrew-packages.nix;
  runner = flake.packages.${pkgs.stdenv.hostPlatform.system}.dogbrew;
  app = flake.apps.${pkgs.stdenv.hostPlatform.system}.dogbrew;
  brewNames = map (entry: lib.removePrefix "datadog/tap/" entry.name)
    (system.homebrew.brews ++ system.homebrew.casks);
  activation = system.system.activationScripts.postActivation.text;
  tests = {
    standaloneApp = app.type == "app" && app.program == lib.getExe runner;
    validPackageNames = builtins.all
      (name: builtins.match "[a-zA-Z0-9][a-zA-Z0-9._+-]*" name != null) packages;
    workspacesRenamed = builtins.elem "workspaces" packages
      && !(builtins.elem "datadog-workspaces" brewNames);
    noDuplicateManagers = lib.intersectLists packages brewNames == [];
    goplsOnDogbrew = builtins.elem "dd-gopls" packages
      && !(builtins.elem "dd-gopls" brewNames);
    blockedReleaseStillOnBrew = builtins.elem "latest-datacenter-config" brewNames;
    nonDestructiveCleanup = system.homebrew.onActivation.cleanup == "none";
    noDarwinActivation = !(system ? dogbrew) && !(lib.hasInfix "dogbrew" activation);
    existingActivationPreserved = lib.hasInfix "/usr/bin/osascript" activation;
    shellSetup = builtins.all (home:
      lib.hasInfix "/opt/dogbrew/share/etc/dogbrew/init.zsh" home.programs.zsh.profileExtra
      && lib.hasInfix "/opt/dogbrew/share/etc/dogbrew/init.zsh" home.programs.zsh.initContent
    ) homes;
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
  # Build the actual app wrapper and check its prefix/package arguments without
  # executing it: tests must never install anything into the real Dogbrew prefix.
  grep -F -- ${lib.escapeShellArg "/opt/dogbrew ${lib.escapeShellArgs packages}"} ${lib.getExe runner}
  python3 ${./dogbrew-sync.py} ${../scripts/dogbrew-sync.sh}
  zsh -n ${../../zshrc/.zshenv}
  zsh -n ${../../zshrc/.zshrc}
  touch "$out"
''
