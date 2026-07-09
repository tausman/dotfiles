{ pkgs, ... }:
{
  programs.home-manager.enable = true;

  home.stateVersion = "24.05";

  # Add ~/.local/bin to PATH declaratively (home-manager writes this into the session
  # vars its generated .zshenv sources). This is where stack installs kmonad and other
  # user binaries. NOTE: the kmonad launchd daemon uses the absolute path, so this is
  # only for running such binaries by name in a shell.
  home.sessionPath = [ "$HOME/.local/bin" ];

  # General-purpose CLI tools not tied to a specific tool module.
  home.packages = with pkgs; [
    curl
    jq
    ripgrep
    fzf
  ];
}
