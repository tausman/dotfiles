{ pkgs, liveLink, ... }:
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

  # Link only the managed files, never all of ~/.pi (which holds sessions and other
  # runtime state). models.json / auth.json stay unmanaged: /refresh-models generates
  # models.json per user with dd.user_email + dd.team baked into the headers.
  # liveLink (not a store copy) because pi writes these itself — `pi install`, the Ctrl+L
  # model picker, `/mcp` — and those writes should land in ~/dotfiles as git diffs.
  home.file.".pi/agent/settings.json" = {
    source = liveLink "pi/.pi/agent/settings.json";
    force = true;
  };
  home.file.".pi/agent/mcp.json" = {
    source = liveLink "pi/.pi/agent/mcp.json";
    force = true;
  };

  # Global instructions. pi loads AGENTS.md *or* CLAUDE.md walking up from cwd, so per-repo
  # CLAUDE.md files already work with no help — but the user-level file it reads is
  # ~/.pi/agent/AGENTS.md, and it never looks at ~/.claude/CLAUDE.md. Point it at the same
  # file claude.nix links so there is one set of global instructions rather than two that
  # drift. Nearly all of that file (jj workflow, gh accounts, preferences, debugging) is
  # harness-neutral; the create-and-push-commit paragraph is Claude-specific and simply
  # inert here, since no such skill exists in pi.
  home.file.".pi/agent/AGENTS.md" = {
    source = liveLink "claude/.claude/CLAUDE.md";
    force = true;
  };

  # Pi 1.4's built-in MCP client reads ~/.pi/agent/mcp.json and trusted project
  # .pi/mcp.json overrides. No pi-mcp-adapter or shared ~/.config/mcp layer is needed.
  # Native OAuth state stays outside this repo in ~/.pi/agent/mcp-auth.json.
  # Trajectory's portable launcher lives at ~/dotfiles/pi/trajectory-mcp.cjs.
  # See pi/README.md for migration details and machine-local config preservation.
}
