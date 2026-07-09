{ pkgs, config, ... }:
{
  # Node.js toolchain. Also what mason.nvim uses to install the JS/TS-based LSP servers
  # (pyright, vtsls, yaml/eslint/vim language servers).
  home.packages = [ pkgs.nodejs ];

  # nix's nodejs points npm's global prefix at the read-only /nix/store, so `npm install -g`
  # fails with EACCES. Redirect the global prefix to a writable dir already on PATH (core.nix
  # adds ~/.local/bin), so global installs land in ~/.local/bin. Neither the mac nor the VM
  # uses volta, so both rely on this. npm keeps its own untracked ~/.npmrc for auth/config,
  # so no secrets end up in the repo.
  home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.local";
}
