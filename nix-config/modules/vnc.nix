{ pkgs, liveLink, ... }:
let
  # Chromium with the password-store nag disabled. Under a bare WM there's no
  # gnome-keyring / dbus secret service, so the default `--password-store=detect`
  # picks the keyring, fails to reach it, and prompts on every launch. The override
  # rebuilds only the wrapper script, not chromium itself, so it's ~free.
  #
  # chromium rather than google-chrome for two reasons: it's free-licensed (google-chrome
  # is unfree, and the flake passes `pkgs` in directly, so home-manager's
  # `nixpkgs.config` is inert and allowUnfree would have to be threaded through
  # flake.nix), and it's prebuilt in the binary cache for aarch64. To switch, set
  # config.allowUnfree in flake.nix's mkHome and change this to pkgs.google-chrome.
  chromium = pkgs.chromium.override {
    commandLineArgs = "--password-store=basic";
  };

  # Bring up the desktop. Xvnc is a *virtual* X server — no display hardware involved,
  # which is exactly why this belongs on a headless box.
  #   -localhost yes  bind loopback only, so the session is unreachable except through
  #                   an SSH tunnel. This is the actual security boundary — reaching the
  #                   session at all requires an SSH key — so never drop it.
  #   -SecurityTypes  chosen from whether ~/.vnc/passwd exists. A VNC password is only a
  #                   weak second factor over the tunnel (8 chars, DES, reversibly
  #                   stored), guarding against other local users on this box. So it's
  #                   optional: skip `vncpasswd` and loopback connections are accepted
  #                   without one; run it later and this picks VncAuth up automatically,
  #                   with no flag to remember. Note macOS's built-in Screen Sharing
  #                   client is fussy about `None` — use TigerVNC Viewer if it refuses.
  #   -geometry       1920x1080 deliberately, not the mac's native retina size. Sending
  #                   2x pixels over the wire quadruples the bandwidth for nothing;
  #                   let macOS scale the window instead.
  vnc-start = pkgs.writeShellScriptBin "vnc-start" ''
    set -eu
    # tigervnc's `vncserver` is a perl script that shells out to these by name, and it
    # is NOT wrapped with them on PATH — without this it dies with
    # `couldn't find "xinit" on your PATH`. Set it here rather than relying on the
    # profile, so the session doesn't depend on how the shell was started; xstartup
    # inherits this environment too.
    #   xinit    launches the session (the failure above)
    #   xauth    writes the ~/.Xauthority cookie the X clients authenticate with
    #   xkbcomp  compiles the keymap; without it the keyboard is dead or scrambled
    export PATH="${pkgs.tigervnc}/bin:${pkgs.xinit}/bin:${pkgs.xauth}/bin:${pkgs.xkbcomp}/bin:$PATH"

    display="''${1:-:1}"
    if [ -f "$HOME/.vnc/passwd" ]; then
      security=VncAuth
    else
      security=None
    fi
    echo "Starting $display (SecurityTypes=$security, loopback only)" >&2
    exec ${pkgs.tigervnc}/bin/vncserver "$display" \
      -geometry 1920x1080 \
      -depth 24 \
      -localhost yes \
      -SecurityTypes "$security"
  '';

  vnc-stop = pkgs.writeShellScriptBin "vnc-stop" ''
    set -eu
    exec ${pkgs.tigervnc}/bin/vncserver -kill "''${1:-:1}"
  '';
in
{
  # A remote desktop for the headless VM: a virtual X server plus a minimal WM, reached
  # from the mac over an SSH tunnel. Imported only by profiles/remote-desktop.nix, so a
  # plain `headless` host is unaffected.
  #
  # Connect from the mac:
  #   ssh -L 5901:localhost:5901 workspace-tausman1   # tunnel (5900 + display number)
  #   open vnc://localhost:5901                       # macOS's built-in client
  #
  # First run on a new VM needs `vncpasswd` once — the password lives in ~/.vnc/passwd,
  # outside nix, since it's a secret.

  home.packages = with pkgs; [
    tigervnc # Xvnc + vncserver/vncpasswd/vncconfig
    i3
    i3status
    dmenu
    xterm # see the terminal comment in the i3 config
    chromium
    vnc-start
    vnc-stop

    # X utilities worth having inside the session.
    xclip # clipboard from the shell
    xrandr # inspect/change the session resolution
    xdpyinfo # confirm the X server is actually up (used to smoke-test this)

    # Fonts. Without these, and without fontconfig below, every web page and UI label
    # renders as tofu boxes: nix packages don't see Ubuntu's system font paths.
    dejavu_fonts
    liberation_ttf # metric-compatible Arial/Times/Courier substitutes for the web
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.hack # same font the mac's terminals use
  ];

  # Generates ~/.config/fontconfig pointing at the nix profile's fonts. Required on a
  # non-NixOS host, where nothing else tells nix-built apps where fonts live.
  fonts.fontconfig.enable = true;

  # Session entry point. tigervnc's `vncserver` runs this with DISPLAY already pointing
  # at the new Xvnc; when it exits, the session ends. Store paths are absolute because
  # this runs with whatever environment vncserver inherited, which may not have the nix
  # profile on PATH.
  home.file.".vnc/xstartup" = {
    executable = true;
    text = ''
      #!/bin/sh
      # Inherited values from the SSH session would point at a bus/session that isn't
      # ours; leave them unset so nothing tries to reuse them.
      unset SESSION_MANAGER DBUS_SESSION_BUS_ADDRESS
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      # Bridges the viewer's clipboard and the X session's selection, so copy/paste
      # between macOS and the desktop works. Without it, clipboard is one-way at best.
      ${pkgs.tigervnc}/bin/vncconfig -nowin &

      exec ${pkgs.i3}/bin/i3
    '';
  };

  # liveLink, not a store copy, so the config is editable in place and `$mod+Shift+r`
  # picks up edits without a home-manager switch.
  home.file.".config/i3/config".source = liveLink "config/.config/i3/config";
}
