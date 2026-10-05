#!/bin/bash
# Export the "Picade Native" preset (Linux arm64) and install it on the cabinet as its own Ports entry,
# next to the web build. Needs the Godot 4.7.1 linux_release.arm64 export template installed.
#
#   bash tools/picade/deploy_native.sh pie@192.168.1.58 [path/to/godot_console.exe]
#
# Uses ~/.ssh/id_ed25519_picade (set up by the pi-game-deploy skill). Restarts EmulationStation.
set -euo pipefail
TARGET="${1:?usage: deploy_native.sh user@host [godot]}"
GODOT="${2:-/c/Users/gotmi/Downloads/Godot_v4.7.1_fixed/Godot_v4.7.1-stable_win64_console.exe}"
SLUG="atomic-robot-native"; NAME="Atomic Robot (Native)"; BIN="atomic_robot.arm64"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$(mktemp -d)"
pi() { ssh -i "$HOME/.ssh/id_ed25519_picade" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8 "$TARGET" "$@"; }

"$GODOT" --headless --path "$ROOT" --export-release "Picade Native" "$OUT/$BIN" > "$OUT/export.log" 2>&1 \
	|| { tail -20 "$OUT/export.log"; exit 1; }

# Refuse to swap the game while someone is playing it.
# Bracketed first letters: the pattern must not match this ssh command's own command line.
if pi "pgrep -f '[a]tomic_robot.arm64|[c]hromium' >/dev/null"; then echo "A game is running on the cabinet; not deploying."; exit 1; fi

tar czf - -C "$OUT" "$BIN" | pi "rm -rf ~/games/$SLUG && mkdir -p ~/games/$SLUG && tar xzf - -C ~/games/$SLUG && chmod +x ~/games/$SLUG/$BIN"
pi 'cat > ~/games/run-native.sh && chmod +x ~/games/run-native.sh' < "$ROOT/tools/picade/run-native.sh"
pi "mkdir -p /opt/retropie/configs/ports/$SLUG && printf 'default = \"run\"\nrun = \"/home/pie/games/run-native.sh $SLUG $BIN\"\n' > /opt/retropie/configs/ports/$SLUG/emulators.cfg"
pi "printf '#!/bin/bash\n/opt/retropie/supplementary/runcommand/runcommand.sh 0 _PORT_ $SLUG \"\"\n' > \"\$HOME/RetroPie/roms/ports/$NAME.sh\" && chmod +x \"\$HOME/RetroPie/roms/ports/$NAME.sh\""
# Missing shared libraries show up here rather than as a silent black screen.
pi "ldd ~/games/$SLUG/$BIN | grep 'not found' || echo 'libs ok'"
pi "md5sum ~/games/$SLUG/$BIN" | cut -c1-32; md5sum "$OUT/$BIN" | cut -c1-32
pi "touch /tmp/es-restart; pkill -f 'supplementary/emulationstation/emulationstation\$' || true"
rm -rf "$OUT"
echo "Deployed $NAME. Launch it from Ports; logs in ~/games/run.log."
