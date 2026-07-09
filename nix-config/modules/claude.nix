{ pkgs, liveLink, ... }:
{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "claude-code"
    ];

  home.packages = [ pkgs.claude-code ];

  # Link only the managed files (never all of ~/.claude, which holds runtime state:
  # sessions, projects, history, cache). Claude writes settings.json at runtime
  # (/model, /config); force overwrites the minimal auto-generated stub.
  home.file.".claude/CLAUDE.md".source = liveLink "claude/.claude/CLAUDE.md";
  home.file.".claude/settings.json" = {
    source = liveLink "claude/.claude/settings.json";
    force = true;
  };
}
