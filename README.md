# Discord Auto Updater for Linux

A safe and portable **auto-updater wrapper** for Discord on Linux.
This replaces the default Discord launcher with a wrapper that:

* Checks the currently installed version
* Downloads the latest release from the official Discord API
* Updates only when needed
* Restarts Discord automatically

---

## ✨ Features

* ✅ **Safe process handling** – only kills legitimate Discord GUI processes (not the updater or unrelated processes)
* ✅ **Cross-distro support**

  * **Debian/Ubuntu** → uses official `.deb` packages
  * **Other distros** → falls back to official `.tar.gz` packages (`/opt/discord`)
* ✅ **Atomic updates** – version is compared before install, minimizing downloads
* ✅ **Stable wrapper path** – lives in `/usr/local/lib/discord-updater/`, not `/tmp`
* ✅ **Locking** – prevents race conditions if you double-launch
* ✅ **Configurable channel** – supports `stable`, `canary`, or `ptb` via `DISCORD_CHANNEL`
* ✅ **Least privilege** – uses `sudo` only for package installation or system-wide changes

---

## 📦 Installation

Run the following commands:

```bash
curl -L https://raw.githubusercontent.com/Doc0x1/Discord-Auto-Updater-For-Linux/master/setup_discord_update.sh -o setup_discord_update.sh
chmod +x setup_discord_update.sh
sudo ./setup_discord_update.sh
```

---

## ⚙️ Usage

Just **launch Discord as usual** from your applications menu or by running:

```bash
discord
```

The wrapper will:

1. Acquire a lock (no multiple updaters running at once)
2. Check your installed version (`build_info.json`)
3. Download the latest `.deb` or `.tar.gz` from Discord’s servers
4. If a newer version exists:

   * Close running Discord instances safely
   * Install the update
   * Relaunch Discord
5. If up to date:

   * Skip update and launch immediately

---

## 🔄 Channels

By default, the updater installs the **stable** release.
To use **canary** or **ptb**, set the environment variable in your shell or profile:

```bash
export DISCORD_CHANNEL=canary
```

Add to `~/.profile` or `~/.bashrc` to make it persistent.

---

## 🗂 Install Paths

* **Debian/Ubuntu (using `.deb`):** `/usr/share/discord`

  * Original binary moved to `/usr/share/discord/Discord.orig`
  * Wrapper replaces `/usr/share/discord/Discord`
* **Other distros (using `.tar.gz`):** `/opt/discord`

  * Wrapper installed as `/usr/local/bin/discord`
  * Desktop entry created in `/usr/local/share/applications/discord.desktop`

---

## 📝 Logs

Logs are stored in:

```
~/.local/state/discord-updater/logs/run.log
```

Useful for troubleshooting update issues.

---

## 🚀 Roadmap

* [ ] Add checksum verification for extra safety
* [ ] Add optional systemd timer for background silent updates
* [ ] Add user config file for advanced settings

---

## ⚠️ Disclaimer

This tool downloads official Discord builds directly from Discord’s API.
It does **not** modify Discord binaries beyond installation. Use at your own risk.
