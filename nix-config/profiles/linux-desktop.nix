{ pkgs, ... }:
{
  # The same applications and config for native Linux and Ubuntu/VNC. The host
  # supplies the display session: NixOS's LightDM/i3 or the remote-desktop add-on.
  imports = [ ./headless.nix ../modules/alacritty.nix ../modules/i3.nix ];

  home.packages = with pkgs; [
    alacritty # the module above supplies settings/font, not the application
    firefox
    ghostty
    xterm # default terminal in the shared i3 config
    dmenu
    i3status
    i3lock
    i3blocks
    xclip
    xrandr
    xdpyinfo
    direnv # used by the shared zsh startup
  ];

  # A single package declaration; the VNC add-on only supplies compatibility flags.
  programs.chromium.enable = true;

  # Register the Hack Nerd Font from alacritty.nix. Native NixOS supplies fallback
  # fonts; the Ubuntu/VNC add-on supplies them for its non-NixOS environment.
  fonts.fontconfig.enable = true;
}
