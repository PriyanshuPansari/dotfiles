#!/usr/bin/env bash
# Generates .desktop entries for all installed Steam games and added non-Steam games
# with box art for the icons to be used with a specifically configured Rofi launcher

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
STEAM_ROOT="$HOME/.local/share/Steam"
APP_PATH="$HOME/.cache/rofi-game-launcher/applications"

# Fetch all Steam library folders.
steam-libraries() {
    echo "$STEAM_ROOT"
    # Additional library folders are recorded in libraryfolders.vdf
    local libraryfolders="$STEAM_ROOT/steamapps/libraryfolders.vdf"
    # Match directories listed in libraryfolders.vdf (or at least all strings
    # that look like directories)
    grep -oP "(?<=\")/.*(?=\")" "$libraryfolders"
}

# Generate the contents of a .desktop file for a game.
# Expects appid/shortcutid, title, launch command, and box art file to be given as arguments
desktop-entry() {
    cat <<EOF
[Desktop Entry]
Name=$2
Exec=$3
Icon=$4
Terminal=false
Type=Application
Categories=SteamLibrary;
EOF
}

# Process non-Steam games from shortcuts.vdf
process-nonsteam-games() {
    local quiet=$1
    local update=$2
    
    # Find all shortcuts.vdf files in userdata directories
    for userdata_dir in "$STEAM_ROOT"/userdata/*; do
        if [ ! -d "$userdata_dir" ]; then
            continue
        fi
        
        local shortcuts_file="$userdata_dir/config/shortcuts.vdf"
        if [ ! -f "$shortcuts_file" ]; then
            continue
        fi
        
        # Extract and process non-Steam game entries
        while IFS= read -r -d $'\0' line; do
            # Extract the game title
            if [[ "$line" =~ ^.*[[:space:]]\"(.*)\"$ ]]; then
                title="${BASH_REMATCH[1]}"
                if [ -n "$title" ] && [ "$title" != "AppName" ] && [ "$title" != "Exe" ] && [ "$title" != "StartDir" ]; then
                    # Calculate shortcut ID (similar to how Steam does it)
                    shortcut_id=$(printf "%u" "0x$(echo -n "$title" | md5sum | head -c 8)")
                    
                    # Skip if entry exists and not doing full update
                    entry="$APP_PATH/shortcut_${shortcut_id}.desktop"
                    if [ -z "$update" ] && [ -f "$entry" ]; then
                        [ -z "$quiet" ] && echo "Not updating $entry"
                        continue
                    fi
                    
                    # Look for grid images (box art)
                    boxart=""
                    for ext in "p.jpg" "p.png" ".jpg" ".png"; do
                        possible_art="$userdata_dir/config/grid/${shortcut_id}${ext}"
                        if [ -f "$possible_art" ]; then
                            boxart="$possible_art"
                            break
                        fi
                    done
                    
                    # # Skip if no box art found
                    # if [ -z "$boxart" ]; then
                    #     [ -z "$quiet" ] && echo "Skipping $title (no box art)"
                    #     continue
                    # fi
                    #
                    # Get the executable path from the next non-empty line
                    local exe_path=""
                    while IFS= read -r -d $'\0' exe_line; do
                        if [[ "$exe_line" =~ ^.*[[:space:]]\"(.*)\"$ ]]; then
                            exe_path="${BASH_REMATCH[1]}"
                            if [ -n "$exe_path" ] && [ "$exe_path" != "AppName" ] && [ "$exe_path" != "Exe" ]; then
                                break
                            fi
                        fi
                    done < <(strings -eS "$shortcuts_file" | tr '\n' '\0')
                    
                    if [ -n "$exe_path" ]; then
                        [ -z "$quiet" ] && echo -e "Generating $entry\t($title)"
                        # Use steam-run for non-Steam games
                        launch_cmd="steam -applaunch $shortcut_id"
                        desktop-entry "$shortcut_id" "$title" "$launch_cmd" "$boxart" > "$entry"
                    fi
                fi
            fi
        done < <(strings -eS "$shortcuts_file" | tr '\n' '\0')
    done
}

update-game-entries() {
    local OPTIND=1
    local quiet update
    while getopts 'qf' arg
    do
        case ${arg} in
            f) update=1;;
            q) quiet=1;;
            *)
                echo "Usage: $0 [-f] [-q]"
                echo "  -f: Full refresh; update existing entries"
                echo "  -q: Quiet; Turn off diagnostic output"
                exit
        esac
    done
    
    mkdir -p "$APP_PATH"
    
    # Process Steam games
    for library in $(steam-libraries); do
        # All installed Steam games correspond with an appmanifest_<appid>.acf file
        if [ -z "$(shopt -s nullglob; echo "$library"/steamapps/appmanifest_*.acf)" ]; then
            # Skip empty library folders
            continue
        fi
        for manifest in "$library"/steamapps/appmanifest_*.acf; do
            appid=$(basename "$manifest" | tr -dc "0-9")
            entry=$APP_PATH/${appid}.desktop
            # Don't update existing entries unless doing a full refresh
            if [ -z $update ] && [ -f "$entry" ]; then
                [ -z $quiet ] && echo "Not updating $entry"
                continue
            fi
            title=$(awk -F\" '/"name"/ {print $4}' "$manifest" | tr -d "™®")
            boxart=$STEAM_ROOT/appcache/librarycache/${appid}_library_600x900.jpg
            # Search for custom boxart set through the Steam library
            boxart_custom_candidates=("$STEAM_ROOT"/userdata/*/config/grid/"${appid}"p.{png,jpg})
            for boxart_custom in "${boxart_custom_candidates[@]}"; do
                [ -e "$boxart_custom" ] && boxart="$boxart_custom"
            done
            # Filter out non-game entries (e.g. Proton versions or soundtracks) by
            # checking for boxart and other criteria
            if [ ! -f "$boxart" ]; then
                [ -z $quiet ] && echo "Skipping $title"
                continue
            fi
            if echo "$title" | grep -qe "Soundtrack"; then
                [ -z $quiet ] && echo "Skipping $title"
                continue
            fi
            [ -z $quiet ] && echo -e "Generating $entry\t($title)"
            desktop-entry "$appid" "$title" "$SCRIPT_DIR/splash-menu.sh $appid" "$boxart" > "$entry"
        done
    done
    
    # Process non-Steam games
    process-nonsteam-games "$quiet" "$update"
}

update-game-entries "$@"
