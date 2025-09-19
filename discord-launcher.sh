#!/usr/bin/env bash
set -euo pipefail

# ---------------- Config ----------------
CHANNEL="${DISCORD_CHANNEL:-stable}"  # stable|canary|ptb
INSTALL_ROOT_DEB="/usr/share/discord"
INSTALL_ROOT_TGZ="/opt/discord"       # generic (non-deb)
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/discord-updater"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/discord-updater/logs"
LOCK_FILE="${STATE_DIR}/update.lock"
mkdir -p "$STATE_DIR" "$LOG_DIR"

# Prefer .deb on Debian/Ubuntu; otherwise tar.gz
IS_DEB=0
if command -v dpkg >/dev/null 2>&1; then
  IS_DEB=1
fi

# Download endpoints
BASE_URL="https://discord.com/api/download"
if [[ $IS_DEB -eq 1 ]]; then
  DL_URL="${BASE_URL}?platform=linux&channel=${CHANNEL}&format=deb"
else
  DL_URL="${BASE_URL}?platform=linux&channel=${CHANNEL}&format=tar.gz"
fi

# ---------------- Utils ----------------
log() { printf '[%s] %s\n' "$(date +'%F %T')" "$*" | tee -a "$LOG_DIR/run.log" ; }

require() {
  command -v "$1" >/dev/null 2>&1 || { log "Missing dependency: $1"; exit 1; }
}

cleanup_tmp() { [[ -n "${TMPDIR_PATH:-}" && -d "${TMPDIR_PATH:-}" ]] && rm -rf "$TMPDIR_PATH" || true; }

# Only kill legit GUI binaries launched from our install root
kill_discord_gui_safely() {
  local root="$1"
  local bins=("Discord" "DiscordCanary" "DiscordPTB")
  local me_uid; me_uid="$(id -u)"
  mapfile -t pids < <(for n in "${bins[@]}"; do pgrep -x -u "$me_uid" "$n" || true; done | sort -u)

  ((${#pids[@]}==0)) && return 0

  local victims=()
  for pid in "${pids[@]}"; do
    [[ -r "/proc/$pid/exe" ]] || continue
    exe="$(readlink -f "/proc/$pid/exe" || true)"
    # Accept main or .orig launcher paths inside the install root
    if [[ "$exe" == "$root/"* ]]; then
      victims+=("$pid")
    fi
  done
  ((${#victims[@]}==0)) && return 0

  log "Requesting Discord to exit (PIDs: ${victims[*]})"
  kill -TERM "${victims[@]}" 2>/dev/null || true

  # Wait up to 8s for clean exit
  for _ in {1..16}; do
    sleep 0.5
    local alive=0
    for pid in "${victims[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then alive=1; break; fi
    done
    ((alive==0)) && break
  done

  # Force kill if needed
  for pid in "${victims[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      log "Force-killing stubborn Discord PID $pid"
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done
}

get_installed_version_from_dir() {
  local dir="$1"
  local f="$dir/resources/build_info.json"
  [[ -f "$f" ]] || { echo "none"; return; }
  jq -r '.version' "$f" 2>/dev/null || echo "unknown"
}

get_latest_version_from_deb() {
  local deb="$1"
  dpkg-deb -f "$deb" Version
}

get_latest_version_from_tgz() {
  local tgz="$1"
  # Extract build_info.json to read version without unpacking everything
  local tmpd; tmpd="$(mktemp -d)"
  tar -xzf "$tgz" --wildcards -C "$tmpd" 'Discord*/resources/build_info.json' >/dev/null 2>&1
  local f; f="$(find "$tmpd" -type f -path '*/resources/build_info.json' | head -n1)"
  local v="unknown"
  if [[ -f "$f" ]]; then
    v="$(jq -r '.version' "$f" 2>/dev/null || echo unknown)"
  fi
  rm -rf "$tmpd"
  echo "$v"
}

# Compare versions using dpkg if available, else a fallback
version_ne() {
  local a="$1" b="$2"
  [[ "$a" != "$b" ]]
}

# Installers
install_deb() {
  local deb="$1"
  require sudo
  sudo dpkg -i "$deb"
}

install_tgz() {
  local tgz="$1"
  require sudo
  local dest="$INSTALL_ROOT_TGZ"
  local tmpx; tmpx="$(mktemp -d)"
  tar -xzf "$tgz" -C "$tmpx"
  # The tar contains Discord-<version>/...
  local src_dir; src_dir="$(find "$tmpx" -maxdepth 1 -type d -name "Discord*" | head -n1)"
  [[ -d "$src_dir" ]] || { log "Failed to locate extracted Discord dir"; rm -rf "$tmpx"; return 1; }

  sudo mkdir -p "$dest"
  sudo rsync -a --delete "$src_dir"/ "$dest"/
  sudo ln -sf "$dest/Discord" /usr/bin/discord
  rm -rf "$tmpx"
}

launch_discord() {
  # Launch whatever we installed
  if [[ $IS_DEB -eq 1 ]]; then
    if [[ -x "$INSTALL_ROOT_DEB/Discord.orig" ]]; then
      nohup "$INSTALL_ROOT_DEB/Discord.orig" >/dev/null 2>&1 &
    elif [[ -x "$INSTALL_ROOT_DEB/Discord" ]]; then
      nohup "$INSTALL_ROOT_DEB/Discord" >/dev/null 2>&1 &
    else
      log "Warning: Discord binary not found in $INSTALL_ROOT_DEB"
    fi
  else
    if [[ -x "$INSTALL_ROOT_TGZ/Discord" ]]; then
      nohup "$INSTALL_ROOT_TGZ/Discord" >/dev/null 2>&1 &
    else
      log "Warning: Discord binary not found in $INSTALL_ROOT_TGZ"
    fi
  fi
}

# ---------------- Main ----------------
require jq
require curl

# Make a temp workspace and lock
TMPDIR_PATH="$(mktemp -d -t discord_update.XXXXXX)"
trap cleanup_tmp EXIT

# Single-instance lock
exec 9>"$LOCK_FILE"
flock -n 9 || { log "Another update instance is running; launching Discord only."; launch_discord; exit 0; }

# Compute current/target versions
if [[ $IS_DEB -eq 1 ]]; then
  INST_DIR="$INSTALL_ROOT_DEB"
else
  INST_DIR="$INSTALL_ROOT_TGZ"
fi
INSTALLED_VERSION="$(get_installed_version_from_dir "$INST_DIR")"

PKG_PATH="$TMPDIR_PATH/pkg"
mkdir -p "$PKG_PATH"
log "Downloading: $DL_URL"
if ! curl -fsSL "$DL_URL" -o "$PKG_PATH/discord.pkg"; then
  log "Download failed; launching existing Discord."
  launch_discord
  exit 0
fi

if [[ $IS_DEB -eq 1 ]]; then
  LATEST_VERSION="$(get_latest_version_from_deb "$PKG_PATH/discord.pkg")"
else
  LATEST_VERSION="$(get_latest_version_from_tgz "$PKG_PATH/discord.pkg")"
fi

log "Installed version: $INSTALLED_VERSION | Latest: $LATEST_VERSION"

if version_ne "$INSTALLED_VERSION" "$LATEST_VERSION"; then
  log "Updating Discord from $INSTALLED_VERSION to $LATEST_VERSION"
  if [[ $IS_DEB -eq 1 ]]; then
    kill_discord_gui_safely "$INSTALL_ROOT_DEB"
    install_deb "$PKG_PATH/discord.pkg"
  else
    kill_discord_gui_safely "$INSTALL_ROOT_TGZ"
    install_tgz "$PKG_PATH/discord.pkg"
  fi
else
  log "Discord is up to date."
fi

launch_discord
