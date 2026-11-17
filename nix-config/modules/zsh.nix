{ pkgs, lib, liveLink, profileName, ... }:
let
  # Static vendor hook: no Dogbrew process or network request at shell startup.
  # Keep the canonical line in the generated files so Dogbrew recognizes setup.
  dogbrewInit = ''
    [ -f "/opt/dogbrew/share/etc/dogbrew/init.zsh" ] && . "/opt/dogbrew/share/etc/dogbrew/init.zsh"
  '';
in
{
  # oh-my-zsh comes from the nixpkgs package (not the dotfiles repo).
  home.packages = [ pkgs.oh-my-zsh ];

  # Config files: live out-of-store symlinks to ~/dotfiles (editable in place; edits and
  # tool-writes propagate straight back to the repo). See `liveLink` in profiles/base.nix.
  home.file.".config/zsh/dotfiles.zshrc".source =
    if profileName == "personal"
    then liveLink "zshrc/.zshrc_personal"
    else liveLink "zshrc/.zshrc";
  home.file.".config/zsh/dotfiles.zshenv".source = liveLink "zshrc/.zshenv";
  home.file.".aliases.zsh".source = liveLink "zshrc/.aliases.zsh";

  # oh-my-zsh stays a store symlink — .zshrc sources $ZSH/oh-my-zsh.sh from here.
  home.file.".oh-my-zsh".source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";

  programs.zsh = {
    enable = true;

    # macOS path_helper runs after .zshenv, so restore package-manager ordering in
    # login shells. Dogbrew also exists on Linux workspaces; its hook is guarded.
    profileExtra = lib.optionalString pkgs.stdenv.isDarwin ''
      if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv zsh)"
      fi
    '' + dogbrewInit;

    envExtra = ''
      source ~/.config/zsh/dotfiles.zshenv
    '';

    initContent = lib.mkMerge [
      # Before Home Manager's compinit (order 570), including non-login shells.
      (lib.mkOrder 550 dogbrewInit)
      (lib.mkOrder 1000 ''
      source ~/.config/zsh/dotfiles.zshrc

      # tmux stores its socket under $TMUX_TMPDIR. Some hosts (workspace containers with no
      # logind-managed /run/user/$UID) point it at a dir we don't own, so tmux can't create
      # its socket. Fall back to /tmp when the target isn't writable. Runs here (late, in the
      # generated ~/.zshrc, after the host's login files set TMUX_TMPDIR) — .zshenv /
      # sessionVariables run too early to win. No-op on macOS / where TMUX_TMPDIR is unset.
      if [ -n "''${TMUX_TMPDIR:-}" ] && [ ! -w "$TMUX_TMPDIR" ]; then
        export TMUX_TMPDIR=/tmp
      fi
      '')
    ];
  };
}
