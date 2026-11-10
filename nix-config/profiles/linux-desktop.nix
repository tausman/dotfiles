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

  # zathura config
  programs.zathura = {
    enable = true;

    options = {
      # Typography & Layout Clutter Removal
      pages-per-row = 1;
      scroll-step = 50;
      statusbar-h-padding = 0;
      statusbar-v-padding = 0;
      show-scrollbars = false;     # Removes distracting vertical/horizontal bars
      save-position = true;        # Remembers exactly what page you left off on

      selection-clipboard = "clipboard";


      # ==========================================
      # DEFAULT MODE (Light Config)
      # ==========================================
      default-bg = "#fdf6e3";
      default-fg = "#000000";
      statusbar-bg = "#c7c7c7";
      statusbar-fg = "#000000";
      inputbar-bg = "#fdf6e3";
      inputbar-fg = "#0c24bf";

      # Text canvas parameters when recolor is FALSE (Light Mode)
      recolor = false; # Start in your light mode text layout

      # ==========================================
      # RECOLOR MODE (Dark High Contrast)
      # ==========================================
      notification-bg = "#000000";
      notification-fg = "#26cd4d";
      notification-error-bg = "#ff9492";
      notification-error-fg = "#000000";

      recolor-lightcolor = "#000000";
      recolor-darkcolor = "#f0f3f6";
    };

    mappings = {
      # Toggle recolor/dark mode with just 'r' instead of 'Ctrl+r'
      "r" = "recolor";

      # Quick intuitive zoom shortcuts using standard keyboard keys
      "minus" = "zoom out";
      "plus" = "zoom in";
    };
  };
}
