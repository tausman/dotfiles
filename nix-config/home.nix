{ pkgs, ... }:

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
  ];

  home.file.".config/zsh/dotfiles.zshrc".source = ../zshrc/.zshrc;
  home.file.".config/zsh/dotfiles.zshenv".source = ../zshrc/.zshenv;
  home.file.".aliases.zsh".source = ../zshrc/.aliases.zsh;

  home.file.".gitconfig".source = ../git/.gitconfig;
  home.file.".git-template/config".source = ../git/.git-template/config;
  home.file.".gitignore".source = ../git/dot-gitignore;

  home.file.".oh-my-zsh".source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";

  home.file.".config/tmux/dotfiles.tmux.conf".source = ../tmux/.tmux.conf;
  home.file.".config/tmux-sessionizer/tmux-sessionizer.conf".source = ../config/.config/tmux-sessionizer/tmux-sessionizer.conf;

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
      resurrect
      continuum
      fzf-tmux-url
    ];
  
    extraConfig = ''
      source-file ~/.config/tmux/dotfiles.tmux.conf
    '';
  };
}
