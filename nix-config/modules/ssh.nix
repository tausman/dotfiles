{ liveLink, ... }:
{
  # SSH drop-in configs from the dotfiles. We link the include files, not ~/.ssh/config
  # itself — install_nix.sh adds the `Include ~/.ssh/custom/*` line to ~/.ssh/config so these
  # load (on the mac the workspaces CLI adds `Include ~/.ssh/workspaces/*` separately).
  #   custom/github-keys.config — fallback per-account identities for github.com and
  #     ddoghq.github.com when the forwarded agent isn't available.
  #   workspaces/01-auth.config — tmux auth bootstrap for `wssh`.
  home.file.".ssh/custom/github-keys.config".source =
    liveLink "ssh/.ssh/custom/github-keys.config";
  home.file.".ssh/workspaces/01-auth.config".source =
    liveLink "ssh/.ssh/workspaces/01-auth.config";
}
