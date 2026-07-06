{ pkgs, lib, ... }:

{
  home.username = "tausif.rahman";
  home.homeDirectory = "/Users/tausif.rahman"; # change for Ubuntu later

  programs.home-manager.enable = true;

  home.stateVersion = "24.05";

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "claude-code"
    ];

  home.packages = with pkgs; [
    git
    gh
    curl
    jq
    ripgrep
    fzf
    neovim
    alacritty
    tmux
    oh-my-zsh
    claude-code
    (pkgs.writeScriptBin "tmux-sessionizer" (builtins.readFile ../scripts/.local/bin/tmux-sessionizer))
    (pkgs.writeScriptBin "tmux-bootstrap-session" (builtins.readFile ../scripts/.local/bin/tmux-bootstrap-session))
    (pkgs.writeScriptBin "tmux-toggle-pane" (builtins.readFile ../scripts/.local/bin/tmux-toggle-pane))
  ];

  # Add ~/.local/bin to PATH declaratively (home-manager writes this into the session
  # vars its generated .zshenv sources). This is where stack installs kmonad and other
  # user binaries. NOTE: the kmonad launchd daemon uses the absolute path, so this is
  # only for running such binaries by name in a shell.
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.file.".config/zsh/dotfiles.zshrc".source = ../zshrc/.zshrc;
  home.file.".config/zsh/dotfiles.zshenv".source = ../zshrc/.zshenv;
  home.file.".aliases.zsh".source = ../zshrc/.aliases.zsh;

  home.file.".gitconfig".source = ../git/.gitconfig;
  home.file.".gitignore".source = ../git/dot-gitignore;

  # NOTE: do NOT manage ~/.git-template/config via home.file. git copies
  # init.templateDir into every new repo's .git/ and PRESERVES symlinks, so a
  # symlink into the read-only nix store makes every new .git/config unwritable
  # ("could not lock config file" on git init/clone). Copy it in as a real,
  # writable file instead.
  home.activation.gitTemplateConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.git-template"
    run rm -f "$HOME/.git-template/config"
    run cp ${../git/.git-template/config} "$HOME/.git-template/config"
    run chmod 644 "$HOME/.git-template/config"
  '';

  home.file.".oh-my-zsh".source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";

  home.file.".config/tmux/dotfiles.tmux.conf".source = ../tmux/.tmux.conf;
  home.file.".config/tmux-sessionizer/tmux-sessionizer.conf".source = ../config/.config/tmux-sessionizer/tmux-sessionizer.conf;

  # kmonad keyboard config, read by the launchd daemon defined in darwin.nix.
  home.file.".config/kmonad.kbd".source = ../kmonad/kmonad.kbd;

  programs.zsh = {
    enable = true;

    profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv zsh)"
    '';

    envExtra = ''
      source ~/.config/zsh/dotfiles.zshenv
    '';

    initExtra = ''
      source ~/.config/zsh/dotfiles.zshrc
    '';
  };

  programs.tmux = {
    enable = true;
  
    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
      # Per-plugin extraConfig is emitted BEFORE the plugin's run-shell, so these
      # options are set before resurrect/continuum load and read them.
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-save 'S'
          set -g @resurrect-restore 'R'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
      fzf-tmux-url
    ];
  
    extraConfig = ''
      source-file ~/.config/tmux/dotfiles.tmux.conf
    '';
  };
}
