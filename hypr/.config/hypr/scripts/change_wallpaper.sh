#!/bin/bash

if ! pgrep -x "swww-daemon" > /dev/null; then
    swww-daemon --format xrgb &
fi
# Set the path to the wallpapers directory



SOURCE_IMAGE="$(realpath "$1")"
SDDM_BG_PATH="${HOME}/.config/wallpaper.img"
MATUGEN_CONFIG="${HOME}/.config/matugen/wallpaper_config.toml"


# Function to validate source image exists
validate_source() {
    if [ -z "$SOURCE_IMAGE" ]; then
        echo "Usage: $0 /path/to/source/image"
        exit 1
    fi

    if [ ! -f "$SOURCE_IMAGE" ]; then
        echo "Error: Source image '$SOURCE_IMAGE' not found"
        exit 1
    fi
}

# Function to validate destination directory exists
validate_destination() {
    DEST_DIR=$(dirname "$SDDM_BG_PATH")
    if [ ! -d "$DEST_DIR" ]; then
        echo "Creating destination directory: $DEST_DIR"
        mkdir -p "$DEST_DIR"
    fi
}

# Function to check if matugen is installed
check_matugen() {
    if ! command -v matugen &> /dev/null; then
        echo "Error: matugen is not installed"
        exit 1
    fi
}

# Main execution
main() {
    validate_source
    validate_destination

    echo "Copying image to SDDM themes directory..."
    if ! cp "$SOURCE_IMAGE" "$SDDM_BG_PATH"; then
        echo "Error: Failed to copy image"
        exit 1
    fi

    check_matugen

    echo "Generating theme with matugen..."
    if ! matugen -c "$MATUGEN_CONFIG" image "$SOURCE_IMAGE"; then
        echo "Error: Failed to generate theme with matugen"
        echo $MATUGEN_CONFIG
        exit 1
    fi

    echo "Theme generation completed successfully!"
}

main

matugen -c "$MATUGEN_CONFIG" image $SOURCE_IMAGE
