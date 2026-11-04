{ pkgs, config, ... }:
{
  # The same applications and config for native Linux and Ubuntu/VNC. The host
  # supplies the display session: NixOS's LightDM/i3 or the remote-desktop add-on.
  imports = [ ./headless.nix ../modules/alacritty.nix ../modules/i3.nix ];

  home.packages = with pkgs; [
    alacritty # the module above supplies settings/font, not the application
    ghostty
    xterm # default terminal in the shared i3 config
    dmenu
    i3status
    i3lock
    i3blocks
    xclip
    xrandr
    xdpyinfo
    xsettingsd
    direnv # used by the shared zsh startup
  ];

  # A single package declaration; the VNC add-on only supplies compatibility flags.
  programs.chromium.enable = true;

  # Register the Hack Nerd Font from alacritty.nix. Native NixOS supplies fallback
  # fonts; the Ubuntu/VNC add-on supplies them for its non-NixOS environment.
  fonts.fontconfig.enable = true;

  # Firefox config
  programs.firefox = {
    enable = true;
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    profiles.default = {
      isDefault = true;
      settings = {
        # Force Firefox to listen strictly to the system theme portals we built
        "layout.css.prefers-color-scheme.content-override" = 3;

        # Optional Quality-of-Life addition: ensure website appearance defaults to system
        "browser.theme.content-theme" = 0;
      };
    };
  };
}
