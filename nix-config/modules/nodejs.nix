{ pkgs, config, ... }:
{
  # Node.js toolchain + the JS-ecosystem tools the DD frontend needs.
  home.packages = with pkgs; [
    # Base Node. Also what mason.nvim uses to install the JS/TS-based LSP servers
    # (pyright, vtsls, yaml/eslint/vim language servers).
    nodejs
    # Node version manager. web-ui pins its exact Node via volta (.node-version /
    # package.json "volta"), so install_nix.sh's web-ui step drives `volta install`.
    # Managed by nix here (no brew) on every host.
    volta
    # File watcher used by web-ui's JS tooling (jest/metro/watchman-based workflows).
    watchman
  ];

  # nix's nodejs points npm's global prefix at the read-only /nix/store, so `npm install -g`
  # fails with EACCES. Redirect the global prefix to a writable dir already on PATH (core.nix
  # adds ~/.local/bin), so global installs (e.g. pi) land in ~/.local/bin before volta sets a
  # default. npm keeps its own untracked ~/.npmrc for auth/config, so no secrets hit the repo.
  home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.local";
}
