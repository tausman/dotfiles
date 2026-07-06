{ pkgs, ... }:

{
  system.stateVersion = 5;

  system.primaryUser = "tausif.rahman";

  nix.settings.experimental-features = "nix-command flakes";

  users.users."tausif.rahman".home = "/Users/tausif.rahman";

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # kmonad (keyboard remapping). The nixpkgs kmonad is built WITHOUT macOS DriverKit
  # (dext) support and segfaults on device access, so the binary must be built from
  # source with `stack install --flag kmonad:dext` (see README.md) — it lands at
  # ~/.local/bin/kmonad. nix-darwin still manages the daemon + config; it just points
  # at that hand-built binary. Also requires the Karabiner-VirtualHIDDevice driver +
  # Input Monitoring grant (manual, one-time — README.md).
  launchd.daemons.kmonad = {
    serviceConfig = {
      ProgramArguments = [
        "/Users/tausif.rahman/.local/bin/kmonad"
        "/Users/tausif.rahman/.config/kmonad.kbd"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/kmonad.out.log";
      StandardErrorPath = "/tmp/kmonad.err.log";
    };
  };

  # The Karabiner-VirtualHIDDevice daemon that kmonad talks to. The driver .pkg is a
  # manual install (README.md), but once installed this daemon lives at a fixed path;
  # dext 4.0.0+ does NOT auto-start it, so nix-darwin runs it at boot. (Until the .pkg
  # is installed the path is missing and the daemon just retries harmlessly.)
  launchd.daemons.karabiner-vhid = {
    serviceConfig = {
      ProgramArguments = [
        "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/karabiner-vhid.out.log";
      StandardErrorPath = "/tmp/karabiner-vhid.err.log";
    };
  };

  system.defaults = {
    dock = {
      autohide = true;
      orientation = "bottom";
      show-recents = false;
    };

    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv";
    };

    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 1;
      InitialKeyRepeat = 10;
    };
  };

  homebrew = {
    enable = true;

    taps = [
      {
        name = "datadog/tap";
        clone_target = "git@github.com:DataDog/homebrew-tap.git";
      }
    ];

    casks = [
      "datadog/tap/ddtool"
    ];

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };
  };
}
