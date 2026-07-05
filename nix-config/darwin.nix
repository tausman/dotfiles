{ pkgs, ... }:

{
  system.stateVersion = 5;

  system.primaryUser = "tausif.rahman";

  nix.settings.experimental-features = "nix-command flakes";

  users.users."tausif.rahman".home = "/Users/tausif.rahman";

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
