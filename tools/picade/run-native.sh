#!/bin/bash
# ~/games/run-native.sh <folder-in-~/games> <binary>  -- launched from EmulationStation Ports via runcommand.
# Runs a native Godot Linux arm64 build under a bare labwc (no Chromium, no desktop), so the whole
# 1 GB Pi goes to the game. labwc -S exits when the game quits, which drops back to ES.
exec >>"$HOME/games/run.log" 2>&1
echo "=== $(date) launch native $1"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
# Own empty labwc config: the system autostart would start the whole Pi desktop (panel, file manager).
LWC="$HOME/.config/picade-labwc"; mkdir -p "$LWC"; : > "$LWC/autostart"
BIN="$HOME/games/$1/$2"
# The Pi 5 GPU offers desktop GL 3.1 but GLES 3.1, and Godot's Compatibility renderer needs GL 3.3
# or GLES 3.0, so ask for GLES directly. Wayland is native under labwc.
labwc -C "$LWC" -S "$BIN --display-driver wayland --rendering-driver opengl3_es --fullscreen"
echo "labwc exited rc=$?"
