{ pkgs, ... }:
{
  # Pi coding agent (github:earendil-works/pi) — MIT, so no allowUnfreePredicate entry
  # is needed here (unlike claude.nix). The nixpkgs derivation wraps $out/bin/pi with
  # ripgrep + fd on PATH, so nothing extra has to be declared for its tool calls.
  #
  # Deliberately nix-managed rather than `npm install -g` (which nodejs.nix's
  # NPM_CONFIG_PREFIX would otherwise make possible): this way pi is pinned by
  # flake.lock and lands on every host from one line in profiles/base.nix.
  #
  # Consequence of that choice: `pi update --self` cannot work, since the store path is
  # read-only. Version bumps come from `nix flake update` instead. Extensions/skills are
  # unaffected — `pi install npm:...` writes to ~/.pi/agent/npm (user) or .pi/npm
  # (project), both writable, and nodejs.nix already provides the node they need.
  home.packages = [ pkgs.pi-coding-agent ];
}
