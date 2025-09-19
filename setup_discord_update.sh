#!/bin/bash

set -e

# Detect package manager
if command -v apt-get &>/dev/null; then
    PACKAGE_MANAGER="apt-get"
    INSTALL_CMD="sudo apt-get install -y"
elif command -v pacman &>/dev/null; then
    PACKAGE_MANAGER="pacman"
    INSTALL_CMD="sudo pacman -S --noconfirm"
else
    echo "Unsupported package manager. Please use a system with APT or Pacman."
    exit 1
fi

# Ensure necessary tools are installed
$INSTALL_CMD jq curl

# Directory where Discord is installed
DISCORD_DIR="/usr/share/discord"

# URL to fetch the latest .deb package
DISCORD_DOWNLOAD_URL="https://discord.com/api/download?platform=linux"

# Temporary directory for downloading the latest package
TEMP_DIR="/tmp/discord_update"

# Wrapper script URL
WRAPPER_SCRIPT_URL="https://raw.githubusercontent.com/Doc0x1/Discord-Auto-Updater-For-Linux/master/discord-launcher.sh"

# Create temp directory if it doesn't exist
mkdir -p "$TEMP_DIR"

# Download the wrapper script
curl -L $WRAPPER_SCRIPT_URL -o $TEMP_DIR/discord-launcher.sh
sudo chmod +x $TEMP_DIR/discord-launcher.sh

# Backup the original Discord launcher and create symlink
if [[ -f "$DISCORD_DIR/Discord" ]]; then
    sudo mv "$DISCORD_DIR/Discord" "$DISCORD_DIR/Discord.orig"
    sudo ln -s $TEMP_DIR/discord-launcher.sh "$DISCORD_DIR/Discord"
    echo "Setup complete. Discord will now be updated automatically when launched."
else
    echo "Discord installation not found in $DISCORD_DIR. Please ensure Discord is installed."
    exit 1
fi
