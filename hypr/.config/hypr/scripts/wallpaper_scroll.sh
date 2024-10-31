#!/bin/bash

# Start swww daemon if not running
if ! pgrep -x "swww-daemon" > /dev/null; then
    swww-daemon --format xrgb &
    sleep 1  # Give daemon time to start
fi

# Set the path to the wallpapers directory
wallpapersDir="$HOME/Pictures/anime/"
MATUGEN_CONFIG="${HOME}/.config/matugen/wallpaper_config.toml"

# Select random wallpaper
selectedWallpaper="$(find $wallpapersDir -type f | shuf -n1)"

# Set the wallpaper
"$HOME/.config/hypr/scripts/change_wallpaper.sh" "$selectedWallpaper"


"$HOME/.config/hypr/scripts/change_sddm_wallpaper.sh" "$selectedWallpaper"
