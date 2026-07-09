{ pkgs, liveLink, ... }:
{
  home.packages = with pkgs; [
    jujutsu
    jjui        # TUI for jj
  ];

  # jj (jujutsu) — `jj config set` writes to this file, so it's a live symlink.
  home.file.".config/jj/config.toml".source = liveLink "jj/.config/jj/config.toml";
}
