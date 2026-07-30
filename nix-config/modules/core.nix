{ pkgs, lib, ... }:
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

  # Terminal file manager (the `n` shell function in the dotfiles uses it). Plugins are
  # fetched declaratively here instead of the imperative `getplugs` curl script, pinned to
  # the same tag as the nixpkgs nnn build so the plugin scripts match the binary's version.
  # `quitcd`/zsh integration is left off: ~/.aliases.zsh's `n()` already implements
  # cd-on-quit by hand via NNN_TMPFILE, so enabling the module's would double it up.
  programs.nnn = {
    enable = true;
    plugins = {
      src =
        (pkgs.fetchFromGitHub {
          owner = "jarun";
          repo = "nnn";
          rev = "v5.2";
          sha256 = "sha256-u+88aDHfOZ6bSkg6ahS6eNZWj2QCwJXKW+8nHR99kic=";
        })
        + "/plugins";
      # Same keys as the pre-nix setup. The original also had `f:fzfopen`, dropped here
      # because no such plugin exists upstream — that key was always a no-op.
      mappings = {
        z = "fzcd"; # fuzzy search filenames, navigate nnn to the match
        o = "fzopen"; # fuzzy search filenames, open the match in $EDITOR
      };
    };
    # fzopen/fzcd shell out to these, so bake them into the wrapper's PATH rather than
    # relying on them being installed globally. `file` is the non-obvious one: fzopen uses
    # `file -biL` to decide $EDITOR vs xdg-open, and without it every pick silently fell
    # through to xdg-open and appeared to do nothing. fd is the fast `find` replacement
    # fzopen prefers when present.
    extraPackages = with pkgs; [
      fzf
      fd
      file
    ];
  };
}
