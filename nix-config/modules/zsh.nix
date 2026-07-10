{ pkgs, lib, liveLink, ... }:
{
  # oh-my-zsh comes from the nixpkgs package (not the dotfiles repo).
  home.packages = [ pkgs.oh-my-zsh ];

  # Config files: live out-of-store symlinks to ~/dotfiles (editable in place; edits and
  # tool-writes propagate straight back to the repo). See `liveLink` in profiles/base.nix.
  home.file.".config/zsh/dotfiles.zshrc".source = liveLink "zshrc/.zshrc";
  home.file.".config/zsh/dotfiles.zshenv".source = liveLink "zshrc/.zshenv";
  home.file.".aliases.zsh".source = liveLink "zshrc/.aliases.zsh";

  # oh-my-zsh stays a store symlink — .zshrc sources $ZSH/oh-my-zsh.sh from here.
  home.file.".oh-my-zsh".source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";

  programs.zsh = {
    enable = true;

    # Put Homebrew's shellenv on the login shell — but only on Darwin: /opt/homebrew
    # doesn't exist on the headless Linux VM, so this is empty there. isDarwin keys off
    # the platform (the honest axis for "is brew here"), independent of host/profile.
    profileExtra = lib.optionalString pkgs.stdenv.isDarwin ''
      eval "$(/opt/homebrew/bin/brew shellenv zsh)"
    '';

    envExtra = ''
      source ~/.config/zsh/dotfiles.zshenv
    '';

    # initContent replaces the deprecated initExtra (default order matches the old
    # after-compinit placement, so behavior is unchanged).
    initContent = ''
      source ~/.config/zsh/dotfiles.zshrc

      # tmux stores its socket under $TMUX_TMPDIR. Some hosts (workspace containers with no
      # logind-managed /run/user/$UID) point it at a dir we don't own, so tmux can't create
      # its socket. Fall back to /tmp when the target isn't writable. Runs here (late, in the
      # generated ~/.zshrc, after the host's login files set TMUX_TMPDIR) — .zshenv /
      # sessionVariables run too early to win. No-op on macOS / where TMUX_TMPDIR is unset.
      if [ -n "''${TMUX_TMPDIR:-}" ] && [ ! -w "$TMUX_TMPDIR" ]; then
        export TMUX_TMPDIR=/tmp
      fi
    '';
  };
}
