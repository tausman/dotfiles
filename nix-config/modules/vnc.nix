{ pkgs, liveLink, ... }:
let
  # Chromium with two flags baked in:
  #   --password-store=basic  under a bare WM there's no gnome-keyring / dbus secret
  #                           service, so the default `detect` picks the keyring, fails
  #                           to reach it, and prompts on every launch.
  #   --disable-gpu           this VM has no GPU and Xvnc exposes no GLX, so chromium
  #                           starts a GPU process that always dies ("GLX is not
  #                           present") before falling back to software rendering. This
  #                           skips the doomed process; rendering is unaffected.
  # The override rebuilds only the wrapper script, not chromium itself, so it's ~free.
  #
  # chromium rather than google-chrome for two reasons: it's free-licensed (google-chrome
  # is unfree, and the flake passes `pkgs` in directly, so home-manager's
  # `nixpkgs.config` is inert and allowUnfree would have to be threaded through
  # flake.nix), and it's prebuilt in the binary cache for aarch64. To switch, set
  # config.allowUnfree in flake.nix's mkHome and change this to pkgs.google-chrome.
  chromium = pkgs.chromium.override {
    commandLineArgs = "--password-store=basic --disable-gpu";
  };

  tigervnc = pkgs.tigervnc;

  # Where logs and the pidfile go. Not ~/.vnc: TigerVNC 1.16 treats that as a legacy
  # path and warns about it if it exists at all.
  stateDir = "$HOME/.local/state/vnc";

  # Bring up the desktop.
  #
  # This drives `Xvnc` directly instead of TigerVNC's `vncserver` wrapper, which cannot
  # work here. In 1.16 that wrapper takes a display and nothing else (all options come
  # from a config file), it ignores ~/.vnc/xstartup entirely, and it locates the session
  # via a hardcoded `/usr/share/xsessions/$name.desktop` — no XDG search path, no home
  # directory. That path doesn't exist on this VM and creating it needs root, which would
  # put the session outside nix. Xvnc takes every option on the command line, so driving
  # it directly keeps the whole thing in user space and under this module's control.
  #
  #   -localhost      bind loopback only, so the session is unreachable except through
  #                   an SSH tunnel. This is the actual security boundary — reaching it
  #                   at all requires an SSH key — so never drop it.
  #   -SecurityTypes  chosen from whether the password file exists. A VNC password is
  #                   only a weak second factor over the tunnel (8 chars, DES, reversibly
  #                   stored), guarding against other local users on this box. So it's
  #                   optional: skip it and loopback connections are accepted without
  #                   one; create one later and this picks VncAuth up automatically.
  #
  #                   BUT: macOS's built-in Screen Sharing client does not support the
  #                   `None` type — it prompts for a password anyway and then can't
  #                   connect. Confirmed in practice, not just in theory. So if that's
  #                   your viewer, you DO need a password:
  #                     mkdir -p ~/.config/tigervnc
  #                     vncpasswd ~/.config/tigervnc/passwd   # max 8 chars, VNC limit
  #                     vnc-stop && vnc-start                 # read at Xvnc startup
  #                   TigerVNC Viewer handles `None` fine and needs none of this.
  #   -geometry       1920x1080 deliberately, not the mac's native retina size. Sending
  #                   2x pixels over the wire quadruples the bandwidth for nothing;
  #                   let macOS scale the window instead.
  #   -AlwaysShared   a reconnect (laptop sleep, dropped tunnel) joins the session rather
  #                   than being refused.
  #
  # No -fp: Xvnc starts fine with no core-X11 font path on this box, and there are no
  # core font dirs to point at anyway. That's why the i3 config runs xterm with an Xft
  # font (-fa) — a bare xterm wants the core `fixed` font and would fail.
  vnc-start = pkgs.writeShellScriptBin "vnc-start" ''
    set -eu

    # Xvnc shells out to xkbcomp by name to compile the keymap. setsid detaches the
    # session so it survives the SSH connection that started it.
    export PATH="${pkgs.xkbcomp}/bin:${pkgs.util-linux}/bin:$PATH"

    display="''${1:-:1}"
    num="''${display#:}"
    port="$((5900 + num))"
    state="${stateDir}"
    mkdir -p "$state"

    # A password file here switches the session to VncAuth. This is the ONLY path
    # consulted, deliberately: -rfbauth below points at it, so checking any other
    # location could select VncAuth while pointing Xvnc at a file that doesn't exist.
    passwd="$HOME/.config/tigervnc/passwd"
    if [ -f "$passwd" ]; then
      security=VncAuth
      auth="-rfbauth $passwd"
    else
      security=None
      auth=""
    fi

    if (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then
      echo "Already running on $display (port $port)." >&2
      exit 0
    fi

    # shellcheck disable=SC2086
    setsid ${tigervnc}/bin/Xvnc "$display" \
      -geometry 1920x1080 \
      -depth 24 \
      -rfbport "$port" \
      -localhost \
      -AlwaysShared \
      -SecurityTypes "$security" \
      -desktop "$(uname -n)$display" \
      $auth >"$state/Xvnc$display.log" 2>&1 &
    echo $! >"$state/Xvnc$display.pid"

    # Wait for the RFB listener rather than sleeping a fixed amount. Plain arithmetic
    # rather than `seq`, to avoid depending on coreutils being on PATH.
    tries=0
    while [ "$tries" -lt 40 ]; do
      if (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then break; fi
      tries="$((tries + 1))"
      sleep 0.25
    done
    if ! (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then
      echo "Xvnc failed to start. Log:" >&2
      tail -20 "$state/Xvnc$display.log" >&2
      exit 1
    fi

    # Bridges the viewer's clipboard and the X session's selection, so copy/paste
    # between macOS and the desktop works. Without it, clipboard is one-way at best.
    DISPLAY="$display" setsid ${tigervnc}/bin/vncconfig -nowin \
      >"$state/vncconfig$display.log" 2>&1 &

    DISPLAY="$display" setsid ${pkgs.i3}/bin/i3 \
      >"$state/i3$display.log" 2>&1 &

    cat >&2 <<EOF
    Desktop up on $display (port $port, SecurityTypes=$security, loopback only).
    From the mac:
      ssh -L $port:localhost:$port workspace-$(uname -n)
      open vnc://localhost:$port
    Logs: $state
    EOF
  '';

  # Killing Xvnc is enough: i3 and every other client lose their display and exit.
  vnc-stop = pkgs.writeShellScriptBin "vnc-stop" ''
    set -eu
    display="''${1:-:1}"
    state="${stateDir}"
    pidfile="$state/Xvnc$display.pid"
    if [ ! -f "$pidfile" ]; then
      echo "No pidfile at $pidfile; nothing to stop." >&2
      exit 0
    fi
    pid="$(cat "$pidfile")"
    if kill "$pid" 2>/dev/null; then
      echo "Stopped $display (pid $pid)." >&2
    else
      echo "Process $pid not running; clearing stale pidfile." >&2
    fi
    rm -f "$pidfile"
  '';
in
{
  # A remote desktop for the headless VM: a virtual X server plus a minimal WM, reached
  # from the mac over an SSH tunnel. Imported only by profiles/remote-desktop.nix, so a
  # plain `headless` host is unaffected.
  #
  #   vnc-start        bring up :1 (pass :2 etc. for another)
  #   vnc-stop         tear it down
  #   vncpasswd        optional — see the -SecurityTypes note above
  #
  # The session survives disconnects, tmux-style; reconnecting rejoins it.

  home.packages = with pkgs; [
    tigervnc # Xvnc + vncpasswd/vncconfig
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
    xdpyinfo # confirm the X server is actually up
    xkbcomp # Xvnc needs it for the keymap; also useful by hand

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

  # liveLink, not a store copy, so the config is editable in place and `$mod+Shift+r`
  # picks up edits without a home-manager switch.
  home.file.".config/i3/config".source = liveLink "config/.config/i3/config";
}
