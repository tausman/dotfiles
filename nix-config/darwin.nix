{ pkgs, ... }:

{
  system.stateVersion = 5;

  system.primaryUser = "tausif.rahman";

  nix.settings.experimental-features = "nix-command flakes";

  users.users."tausif.rahman".home = "/Users/tausif.rahman";

  # GUI apps here (rather than home.nix's home.packages) get symlinked by nix-darwin's
  # activation script into /Applications/Nix Apps, so they're visible to
  # Spotlight/Launchpad/Dock — home-manager packages don't get that treatment.
  environment.systemPackages = [
    pkgs.alacritty
    pkgs.drawio
    pkgs.rectangle
  ];

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

  # Solid desktop wallpaper matching the Alacritty (kanagawa dark theme) background
  # color #121212. assets/black.png is a 1x1 PNG of that color — regenerate it if the
  # theme's background changes.
  system.activationScripts.postActivation.text = ''
    /usr/bin/osascript -e 'tell application "System Events" to tell every desktop to set picture to "${./assets/black.png}"'

    # Login screen / account avatar: same solid-black asset as the wallpaper above.
    # The login window renders the account's JPEGPhoto attribute (raw image bytes in
    # the directory record), NOT the Picture attribute (just a file path) — so setting
    # Picture alone leaves the old avatar. dscl can't write binary attributes, so the
    # image bytes are loaded via dsimport with an externalbinary mapping. This runs as
    # root during activation, so no sudo needed.
    tmp=$(/usr/bin/mktemp)
    /usr/bin/printf '0x0A 0x5C 0x3A 0x2C dsRecTypeStandard:Users 2 dsAttrTypeStandard:RecordName externalbinary:dsAttrTypeStandard:JPEGPhoto\ntausif.rahman:%s\n' "${./assets/black.png}" > "$tmp"
    /usr/bin/dscl . -delete /Users/tausif.rahman JPEGPhoto || true
    /usr/bin/dscl . -delete /Users/tausif.rahman Picture || true
    /usr/bin/dsimport "$tmp" /Local/Default M
    /usr/bin/dscl . -create /Users/tausif.rahman Picture "${./assets/black.png}"
    /bin/rm -f "$tmp"
  '';

  system.defaults = {
    dock = {
      autohide = true;
      orientation = "bottom";
      show-recents = false;
      # Only show currently-running apps in the Dock, no persistent icons.
      static-only = true;
    };

    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv";
    };

    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 1;
      InitialKeyRepeat = 10;
      # Auto-hide the menu bar (reveals on hover to the top edge).
      _HIHideMenuBar = true;
    };

    # Trackpad tracking speed. Not a typed nix-darwin option, so it's set as a raw
    # default. Default is ~0.6875, macOS caps the System Settings slider around 3.0.
    CustomUserPreferences.NSGlobalDomain."com.apple.trackpad.scaling" = 1.625;
  };

  homebrew = {
    enable = true;

    taps = [
      {
        name = "datadog/tap";
        clone_target = "git@github.com:DataDog/homebrew-tap.git";
      }
    ];

    # git and go are also nix-managed in home.nix, but they're top-level brew installs
    # (leaves) too — declared here for a faithful brew state. jq is only a brew
    # dependency (not a leaf), so it's auto-resolved and intentionally not listed.
    brews = [
      # dev tools (from laptop-setup ansible)
      "aws-vault"
      "awscli"
      "bazelisk"
      "coreutils"
      "direnv"
      "gcc"
      "gimme"
      "git"
      "gnupg"
      "go"
      "grep"
      "helm"
      "kubectx"
      "make"
      "mkcert"
      "nss"
      "pinentry"
      "pre-commit"
      "pyenv"
      "rbenv"
      "tfenv"
      "wget"
      # Datadog tap CLI tools
      "datadog/tap/devkube"
      "datadog/tap/docker-local-dev"
      "datadog/tap/kubectl-analyse"
      "datadog/tap/kubectl-iscale"
      "datadog/tap/kubectl-multiexec"
      "datadog/tap/kubectl-template"
      "datadog/tap/latest-chart"
      "datadog/tap/latest-datacenter-config"
      "datadog/tap/latest-image"
      "datadog/tap/sce"
      "datadog/tap/to-prod"
      "datadog/tap/to-staging"
      "datadog/tap/trigger-ci"
      "datadog/tap/vault"
      "datadog/tap/orgstore"
    ];

    casks = [
      "1password-cli"
      "claude"
      "gcloud-cli"
      # Datadog tap casks
      "datadog/tap/dd-auth"
      "datadog/tap/atlas"
      "datadog/tap/bzl"
      "datadog/tap/datadog-workspaces"
      "datadog/tap/dd-gopls"
      "datadog/tap/ddcall"
      "datadog/tap/ddr"
      "datadog/tap/ddtool"
      "datadog/tap/git-dd"
      "datadog/tap/rapid"
    ];

    onActivation = {
      autoUpdate = true;
      # "none": nix-darwin won't remove Homebrew packages it doesn't manage. Needed
      # because laptop-setup (ansible) installs lots of brew packages imperatively —
      # "zap"/"uninstall" would delete them on every darwin-rebuild. Tighten back to
      # "zap" only once everything you want is declared here.
      cleanup = "none";
    };
  };
}
