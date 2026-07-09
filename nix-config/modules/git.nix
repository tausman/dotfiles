{ pkgs, lib, liveLink, ... }:
{
  home.packages = with pkgs; [
    git
    gh    # GitHub CLI (also used by install.sh auth)
  ];

  home.file.".gitconfig".source = liveLink "git/.gitconfig";
  home.file.".gitignore".source = liveLink "git/dot-gitignore";

  # ~/.git-template/config is intentionally a REAL file (copied via activation), not a
  # symlink: `init.templateDir` makes git copy this into every new repo's .git/, and git
  # preserves symlinks when copying — so a symlink here would make each new repo's
  # .git/config a symlink to one shared file (they'd clobber each other). A real file
  # means git copies the CONTENT, giving each repo its own independent .git/config.
  home.activation.gitTemplateConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.git-template"
    run rm -f "$HOME/.git-template/config"
    run cp ${../../git/.git-template/config} "$HOME/.git-template/config"
    run chmod 644 "$HOME/.git-template/config"
  '';
}
