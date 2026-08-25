{ liveLink, ... }:
{
  # AeroSpace itself is a Homebrew cask (see darwin.nix); this module just links its
  # config. The cask reads ~/.config/aerospace/aerospace.toml by default, so no
  # --config-path is needed. Kept out of nix-darwin's own `services.aerospace` (which
  # generates the TOML into /nix/store) so the config stays editable in place and
  # `alt-shift-c` picks up changes without a darwin-rebuild — same reasoning as the
  # i3 config on the Linux side.
  home.file.".config/aerospace/aerospace.toml".source =
    liveLink "config/.config/aerospace/aerospace.toml";
}
