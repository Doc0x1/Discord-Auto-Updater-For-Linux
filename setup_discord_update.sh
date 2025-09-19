#!/usr/bin/env bash
set -euo pipefail

WRAP_DIR="/usr/local/lib/discord-updater"
WRAP_BIN="$WRAP_DIR/discord-launcher.sh"

DISCORD_DEB_DIR="/usr/share/discord"   # on Debian/Ubuntu installs
TARGET_LAUNCHER="$DISCORD_DEB_DIR/Discord"

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }

require curl
require jq

sudo mkdir -p "$WRAP_DIR"
sudo curl -fsSL "https://raw.githubusercontent.com/Doc0x1/Discord-Auto-Updater-For-Linux/master/discord-launcher.sh" \
  -o "$WRAP_BIN"

# If you’ll host the new wrapper in this gist, point to it; otherwise write the file yourself before running.
# For convenience in testing, comment the curl above and copy the wrapper content locally, then:
sudo chmod +x "$WRAP_BIN"

if [[ -d "$DISCORD_DEB_DIR" && -x "$TARGET_LAUNCHER" ]]; then
  # Debian-style install — move original to .orig once
  if [[ ! -e "${TARGET_LAUNCHER}.orig" ]]; then
    echo "Backing up original Discord launcher to ${TARGET_LAUNCHER}.orig"
    sudo mv "$TARGET_LAUNCHER" "${TARGET_LAUNCHER}.orig"
  fi
  # Replace entry point with our wrapper (symlink)
  if [[ -L "$TARGET_LAUNCHER" ]]; then
    sudo rm -f "$TARGET_LAUNCHER"
  fi
  sudo ln -s "$WRAP_BIN" "$TARGET_LAUNCHER"
  echo "Setup complete for Debian-based install. Launching Discord will auto-update."
else
  # Non-deb systems: Create a generic desktop entry & /usr/bin/discord pointer to wrapper
  sudo install -m 0755 -D "$WRAP_BIN" /usr/local/bin/discord
  # Optional: create/patch a desktop file that calls /usr/local/bin/discord
  DESKTOP_FILE="/usr/local/share/applications/discord.desktop"
  sudo mkdir -p "$(dirname "$DESKTOP_FILE")"
  sudo bash -c "cat > '$DESKTOP_FILE' <<'EOF'
[Desktop Entry]
Name=Discord
Comment=All-in-one voice and text chat
Exec=/usr/local/bin/discord
Icon=discord
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
EOF"
  echo "Setup complete for generic install. Menu/launchers will call the updater-wrapper."
fi

echo
echo "Tip: set CHANNEL on your user session to use canary/PTB, e.g.:"
echo "  echo 'export DISCORD_CHANNEL=canary' >> ~/.profile"
