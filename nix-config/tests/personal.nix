# Evaluation/regression checks for the imported machine. The resulting derivation
# runs on the caller's platform; it does NOT build or activate the NixOS closure.
{ pkgs, flake }:
let
  inherit (pkgs) lib;
  system = flake.nixosConfigurations.personal.config;
  home = system.home-manager.users.t;
  packages = map lib.getName home.home.packages;
  vncHomes = map (name: flake.homeConfigurations.${name}.config) [
    "ubuntu-aarch64-desktop"
    "ubuntu-x86_64-desktop"
    "ubuntu-x86_64-desktop-personal"
  ];
  desktopHomes = [ home ] ++ vncHomes;
  keyboard = system.services.kmonad.keyboards.builtin;
  keyboardInput = "(device-file ${builtins.toJSON keyboard.device})";
  keyboardOutput = ''(uinput-sink "kmonad-builtin")'';
  keyboardService = system.systemd.services.kmonad-builtin.serviceConfig;
  sharedKeymap = builtins.readFile ../../kmonad/kmonad.kbd;
  systemPackages = map lib.getName system.environment.systemPackages;
  allHomes = [ home ] ++ map (entry: entry.config) (builtins.attrValues flake.homeConfigurations);

  tests = {
    architecture = system.nixpkgs.hostPlatform.system == "x86_64-linux";
    hostname = system.networking.hostName == "nixos";
    stateVersions = system.system.stateVersion == "26.05" && home.home.stateVersion == "24.05";
    boot = system.boot.loader.systemd-boot.enable
      && system.boot.loader.efi.canTouchEfiVariables
      && system.fileSystems."/".fsType == "ext4"
      && system.fileSystems."/boot".fsType == "vfat"
      && builtins.length (builtins.attrNames system.boot.initrd.luks.devices) == 1;
    hardware = system.hardware.cpu.intel.npu.enable
      && builtins.elem "kvm-intel" system.boot.kernelModules;
    kernel = system.boot.kernelPackages.kernel.version
      == flake.inputs.nixpkgs.legacyPackages.x86_64-linux.linuxPackages_latest.kernel.version;
    networking = system.networking.networkmanager.enable && system.services.openssh.enable;
    locale = system.time.timeZone == "America/New_York" && system.i18n.defaultLocale == "en_US.UTF-8";
    desktop = system.services.xserver.enable
      && system.services.xserver.displayManager.lightdm.enable
      && system.services.xserver.windowManager.i3.enable;
    account = system.users.users.t.isNormalUser
      && system.users.users.t.home == "/home/t"
      && builtins.elem "wheel" system.users.users.t.extraGroups
      && home.home.username == "t" && home.home.homeDirectory == "/home/t";
    shell = system.programs.zsh.enable && home.programs.zsh.enable
      && lib.getName system.users.users.t.shell == "zsh";
    flakes = builtins.elem "flakes" system.nix.settings.experimental-features
      && builtins.elem "nix-command" system.nix.settings.experimental-features;
    integratedHome = system.home-manager.useUserPackages
      && system.home-manager.backupFileExtension == "before-home-manager"
      && system.systemd.services ? home-manager-t;
    sharedDesktopPackages = lib.all (userHome:
      lib.all (name: builtins.elem name (map lib.getName userHome.home.packages)) [
        "alacritty" "firefox" "chromium" "ghostty" "xterm" "dmenu" "i3status"
        "i3lock" "i3blocks" "xclip" "xrandr" "xdpyinfo" "direnv" "git" "neovim" "gh"
      ]
    ) desktopHomes;
    singleDesktopInstall = lib.all (userHome:
      lib.all (name:
        builtins.length (builtins.filter (package: lib.getName package == name) userHome.home.packages) == 1
      ) [ "alacritty" "chromium" "xterm" "nerd-fonts-hack" ]
    ) desktopHomes;
    neovimOwnedByHome = builtins.length (builtins.filter (name: name == "neovim") packages) == 1
      && !(lib.any (package: lib.getName package == "neovim") system.environment.systemPackages);
    noRemoteDesktop = lib.all (name: !(builtins.elem name packages))
      [ "tigervnc" "nixGLIntel" "vnc-start" "vnc-stop" ];
    fonts = home.fonts.fontconfig.enable;
    fontOwnership = builtins.elem "nerd-fonts-hack" packages
      && lib.all (name: !(builtins.elem name packages))
        [ "dejavu-fonts" "noto-fonts" "noto-fonts-color-emoji" ]
      && lib.all (name: builtins.elem name (map lib.getName system.fonts.packages))
        [ "dejavu-fonts" "noto-fonts-color-emoji" ];
    sharedI3Config = lib.all (userHome:
      toString userHome.home.file.".config/i3/config".source
      == toString (userHome.lib.file.mkOutOfStoreSymlink
        "${userHome.home.homeDirectory}/dotfiles/config/.config/i3/config")
      && !(userHome.home.file ? ".config/i3/bindings")
    ) desktopHomes;
    vncOnlyChromiumFlags = home.programs.chromium.commandLineArgs == []
      && lib.all (userHome: userHome.programs.chromium.commandLineArgs == [
        "--password-store=basic" "--disable-gpu" "--disable-dev-shm-usage"
      ]) vncHomes;
    vncServerInstalled = lib.all (userHome:
      lib.all (name: builtins.elem name (map lib.getName userHome.home.packages))
        [ "tigervnc" "i3" "xkbcomp" "vnc-start" "vnc-stop" ]
    ) vncHomes;
    headlessStaysHeadless = lib.all (name:
      let cfg = flake.homeConfigurations.${name}.config; in
      !cfg.programs.chromium.enable && !(cfg.home.file ? ".config/i3/config")
    ) [ "ubuntu-aarch64" "ubuntu-x86_64" ];
    terminalConfig = toString home.home.file.".config/alacritty".source
      == toString (home.lib.file.mkOutOfStoreSymlink "/home/t/dotfiles/config/.config/alacritty");
    existingHomeTargets = builtins.attrNames flake.homeConfigurations == [
      "default"
      "ubuntu-aarch64"
      "ubuntu-aarch64-desktop"
      "ubuntu-x86_64"
      "ubuntu-x86_64-desktop"
      "ubuntu-x86_64-desktop-personal"
    ];
    existingDarwinTarget = builtins.attrNames flake.darwinConfigurations == [ "default" ];
    sharedBuildTools = lib.all (name:
      !(builtins.elem name systemPackages)
      && lib.all (userHome:
        builtins.length (builtins.filter (package: lib.getName package == name) userHome.home.packages) == 1
      ) allHomes
    ) [ "gnumake" "cmake" "gcc-wrapper" "clang-wrapper" ];
    gccDefault = lib.all (userHome:
      let
        gcc = lib.findFirst (package: lib.getName package == "gcc-wrapper") null userHome.home.packages;
        clang = lib.findFirst (package: lib.getName package == "clang-wrapper") null userHome.home.packages;
      in gcc != null && clang != null
        && (gcc.meta.priority or 5) < (clang.meta.priority or 5)
    ) allHomes;
    kmonadBuiltInOnly = system.services.kmonad.enable
      && builtins.attrNames system.services.kmonad.keyboards == [ "builtin" ]
      && keyboard.device == "/dev/input/by-path/platform-i8042-serio-0-event-kbd";
    kmonadLinuxBackends = !keyboard.defcfg.enable
      && lib.hasInfix keyboardInput keyboard.config
      && lib.hasInfix keyboardOutput keyboard.config
      && !(lib.hasInfix "(iokit-name)" keyboard.config)
      && !(lib.hasInfix "(kext)" keyboard.config);
    kmonadSharedMapping = lib.replaceStrings
      [ keyboardInput keyboardOutput ] [ "(iokit-name)" "(kext)" ]
      keyboard.config == sharedKeymap;
    kmonadSafeConfig = lib.hasInfix "fallthrough true" keyboard.config
      && lib.hasInfix "allow-cmd false" keyboard.config;
    kmonadDeviceActivation = system.hardware.uinput.enable
      && builtins.elem "uinput" system.boot.kernelModules
      && system.systemd.paths.kmonad-builtin.pathConfig.PathExists == keyboard.device
      && builtins.elem "paths.target" system.systemd.paths.kmonad-builtin.wantedBy;
    kmonadServicePermissions = keyboard.enableHardening
      && keyboardService.DynamicUser
      && keyboardService.DevicePolicy == "closed"
      && keyboardService.ProtectHome
      && lib.all (group: builtins.elem group keyboardService.SupplementaryGroups) [ "input" "uinput" ]
      && lib.all (group: !(builtins.elem group system.users.users.t.extraGroups)) [ "input" "uinput" ];
  };
  failed = builtins.filter (name: !tests.${name}) (builtins.attrNames tests);
in
assert lib.assertMsg (failed == []) "Failed personal NixOS checks: ${lib.concatStringsSep ", " failed}";
# Force full system evaluation, including module assertions and package policy.
# Do not put this store path in the check's inputs: that would build Linux on macOS.
builtins.seq system.system.build.toplevel.drvPath (
  pkgs.runCommand "nixos-personal-check" {
    report = builtins.toJSON tests;
    passAsFile = [ "report" ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  } ''
    cp "$reportPath" "$out"
  ''
)
