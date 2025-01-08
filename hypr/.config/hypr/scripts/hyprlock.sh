#!/usr/bin/env bash
sleep 0.6
grim -o eDP-1 -l 0 /tmp/hyprlock_screenshot1.png & # run this command in background
# hyprshot -o eDP-1 -l 0 /tmp/hyprlock_screenshot1.png & # idem
# # wait && # wait background commands to finish. But if hyprlock spawn time (at least until the background image pick step) > the time to take the screeshot(s), you don't have to wait at all :')
hyprlock # so hyprlock will only start when screenshot(s) are done
