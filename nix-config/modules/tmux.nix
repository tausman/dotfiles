{ pkgs, liveLink, ... }:
{
  home.packages = with pkgs; [
    tmux
    (writeScriptBin "tmux-sessionizer" (builtins.readFile ../../scripts/.local/bin/tmux-sessionizer))
    (writeScriptBin "tmux-bootstrap-session" (builtins.readFile ../../scripts/.local/bin/tmux-bootstrap-session))
    (writeScriptBin "tmux-toggle-pane" (builtins.readFile ../../scripts/.local/bin/tmux-toggle-pane))
  ];

  home.file.".config/tmux/dotfiles.tmux.conf".source = liveLink "tmux/.tmux.conf";
  home.file.".config/tmux-sessionizer/tmux-sessionizer.conf".source =
    liveLink "config/.config/tmux-sessionizer/tmux-sessionizer.conf";

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
