#!/usr/bin/env bash
XSETTINGS="$HOME/.xsettingsd"
ALACRITTY_DIR="$HOME/.config/alacritty"

if grep -q "Net/ColorScheme 1" "$XSETTINGS" 2>/dev/null; then
    # --- SWITCH TO LIGHT MODE ---
    echo "Net/ColorScheme 2" > "$XSETTINGS"
    echo "Gtk/EnableAnimations 1" >> "$XSETTINGS"
    ln -sf "$ALACRITTY_DIR/my_themes/light.toml" "$ALACRITTY_DIR/active_theme.toml"
    dconf write /org/gnome/desktop/interface/color-scheme "'default'"
else
    # --- SWITCH TO DARK MODE ---
    echo "Net/ColorScheme 1" > "$XSETTINGS"
    echo "Gtk/EnableAnimations 1" >> "$XSETTINGS"
    ln -sf "$ALACRITTY_DIR/my_themes/dark.toml" "$ALACRITTY_DIR/active_theme.toml"
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
fi

# Instantly broadcast the theme change
killall -HUP xsettingsd
