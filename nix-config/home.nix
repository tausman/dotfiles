{ pkgs, lib, config, ... }:
let
  # Live out-of-store symlink to the working copy in ~/dotfiles: the system location
  # points at the real repo file, so it's editable in place, tools can write to it, and
  # changes show up directly as git diffs — no `home-manager switch` needed after edits.
  # Used instead of read-only /nix/store copies (which break anything that writes to the
  # file: gitconfig, claude settings, jj config, lazy-lock, etc.).
  dotfiles = "${config.home.homeDirectory}/dotfiles";
  liveLink = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
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
    tmux
    nerd-fonts.hack # for Alacritty's "Hack Nerd Font Mono"
    oh-my-zsh
    claude-code
    jujutsu
    jjui             # TUI for jj
    # Rust toolchain (nix-managed — cargo/rustc land on PATH directly, so there's no
    # rustup-style ~/.cargo/env; the zshrc sources that file only if it exists).
    rustc
    cargo
    clippy
    rustfmt
    rust-analyzer
    # Build tool for compiling native nvim plugins (e.g. telescope-fzf-native).
    cmake
    # Toolchains mason.nvim needs to install LSP servers:
    #   go  → gopls;  nodejs (npm) → pyright, vtsls, yaml/eslint/vim language servers.
    go
    nodejs
    # tree-sitter CLI — nvim-treesitter (main branch) uses it to generate/compile parsers.
    tree-sitter
    (pkgs.writeScriptBin "tmux-sessionizer" (builtins.readFile ../scripts/.local/bin/tmux-sessionizer))
    (pkgs.writeScriptBin "tmux-bootstrap-session" (builtins.readFile ../scripts/.local/bin/tmux-bootstrap-session))
    (pkgs.writeScriptBin "tmux-toggle-pane" (builtins.readFile ../scripts/.local/bin/tmux-toggle-pane))
  ];

  # Add ~/.local/bin to PATH declaratively (home-manager writes this into the session
  # vars its generated .zshenv sources). This is where stack installs kmonad and other
  # user binaries. NOTE: the kmonad launchd daemon uses the absolute path, so this is
  # only for running such binaries by name in a shell.
  home.sessionPath = [ "$HOME/.local/bin" ];

  # --- Config files: live out-of-store symlinks to ~/dotfiles (editable in place;
  # edits/tool-writes propagate straight back to the repo). See `liveLink` above. ---
  home.file.".config/zsh/dotfiles.zshrc".source = liveLink "zshrc/.zshrc";
  home.file.".config/zsh/dotfiles.zshenv".source = liveLink "zshrc/.zshenv";
  home.file.".aliases.zsh".source = liveLink "zshrc/.aliases.zsh";

  home.file.".gitconfig".source = liveLink "git/.gitconfig";
  home.file.".gitignore".source = liveLink "git/dot-gitignore";

  home.file.".config/tmux/dotfiles.tmux.conf".source = liveLink "tmux/.tmux.conf";
  home.file.".config/tmux-sessionizer/tmux-sessionizer.conf".source =
    liveLink "config/.config/tmux-sessionizer/tmux-sessionizer.conf";

  # kmonad keyboard config, read by the launchd daemon defined in darwin.nix.
  home.file.".config/kmonad.kbd".source = liveLink "kmonad/kmonad.kbd";

  # jj (jujutsu) — `jj config set` writes to this file.
  home.file.".config/jj/config.toml".source = liveLink "jj/.config/jj/config.toml";

  # Neovim — lazy.nvim writes lazy-lock.json into the config dir.
  home.file.".config/nvim".source = liveLink "config/.config/nvim";

  # Alacritty — installed as a GUI app via darwin.nix's environment.systemPackages;
  # this links config + themes.
  home.file.".config/alacritty".source = liveLink "config/.config/alacritty";

  # Claude Code — link only the managed files (never all of ~/.claude, which holds
  # runtime state: sessions, projects, history, cache). Claude writes settings.json at
  # runtime (/model, /config); force overwrites the minimal auto-generated stub.
  home.file.".claude/CLAUDE.md".source = liveLink "claude/.claude/CLAUDE.md";
  home.file.".claude/settings.json" = {
    source = liveLink "claude/.claude/settings.json";
    force = true;
  };

  # oh-my-zsh comes from the nixpkgs package (not the dotfiles repo), so it stays a
  # store symlink — .zshrc sources $ZSH/oh-my-zsh.sh from here.
  home.file.".oh-my-zsh".source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";

  # ~/.git-template/config is intentionally a REAL file (copied via activation), not a
  # symlink: `init.templateDir` makes git copy this into every new repo's .git/, and git
  # preserves symlinks when copying — so a symlink here would make each new repo's
  # .git/config a symlink to one shared file (they'd clobber each other). A real file
  # means git copies the CONTENT, giving each repo its own independent .git/config.
  home.activation.gitTemplateConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.git-template"
    run rm -f "$HOME/.git-template/config"
    run cp ${../git/.git-template/config} "$HOME/.git-template/config"
    run chmod 644 "$HOME/.git-template/config"
  '';

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
