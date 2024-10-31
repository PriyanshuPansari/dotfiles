#!/bin/bash

# Configuration
WALLPAPER_DIR="$HOME/Pictures/anime"
SCRIPT_DIR="$HOME/.config/hypr/scripts"

# Function to show wallpaper selection
select_wallpaper() {
    find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) -printf "%f\n"
}

case "$ROFI_RETV" in
    0) # Initial call from rofi
        select_wallpaper
        ;;
    1) # Item selected
        if [ ! -z "$1" ]; then
            wallpaper_path="$WALLPAPER_DIR/$1"
            if [ -f "$wallpaper_path" ]; then
                case "$0" in
                    *desktop-wall)
                        "$SCRIPT_DIR/change-wallpaper" "$wallpaper_path"
                        ;;
                    *sddm-wall)
                        "$SCRIPT_DIR/change-sddm-wallpaper" "$wallpaper_path"
                        ;;
                esac
            fi
        fi
        ;;
esac
