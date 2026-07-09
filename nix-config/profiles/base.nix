{ config, ... }:
{
  # The shared bundle every host gets, regardless of role or platform.
  imports = [
    ../modules/core.nix
    ../modules/git.nix
    ../modules/zsh.nix
    ../modules/tmux.nix
    ../modules/neovim.nix
    ../modules/jj.nix
    ../modules/claude.nix
    ../modules/dev.nix
  ];

  # `liveLink` — an out-of-store symlink to the working copy in ~/dotfiles: the deployed
  # location points at the real repo file, so it's editable in place, tools can write to
  # it, and changes show up directly as git diffs (no `home-manager switch` after edits).
  # Used instead of read-only /nix/store copies (which break anything that writes to the
  # file: gitconfig, claude settings, jj config, lazy-lock, etc.).
  #
  # Published via _module.args so every module can take it as a plain argument
  # (`{ liveLink, ... }:`) without redefining it. The ~/dotfiles path is derived from
  # home.homeDirectory, which each host file sets.
  _module.args.liveLink = path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/${path}";
}
