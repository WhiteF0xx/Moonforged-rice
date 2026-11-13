# Moonforge Installation Guide

Moonforge is a personal Arch Linux / Hyprland configuration project. These instructions describe how to install the current configuration on Arch Linux, using the included installer or the manual steps below.

> **Important:** Moonforge is still evolving and is not a universal one-click desktop setup. Review the configuration and adapt machine-specific settings before applying it. The installer backs up files it replaces and never overwrites an existing Hyprland configuration. Manual copying, however, can overwrite files, so back them up first.

## 1. Quick installation (recommended)

Clone the repository and enter its directory:

```bash
mkdir -p ~/Projects
git clone https://github.com/WhiteF0xx/moonforged-rice.git ~/Projects/moonforged-rice
cd ~/Projects/moonforged-rice
chmod +x install.sh
```

Run the interactive installer:

```bash
./install.sh
```

The installer checks for Arch Linux, offers to install the required official packages, installs the Moonforge configuration, and can enable NetworkManager. Existing files are backed up before replacement. An existing `~/.config/hypr/hyprland.conf` is deliberately protected and is never replaced; merge the sample settings manually if needed.

### Installer options

| Command | Behavior |
|---|---|
| `./install.sh` | Interactive installation |
| `./install.sh --yes` | Automatically accept package installation, file replacements, and NetworkManager activation |
| `./install.sh --no-packages` | Skip pacman; use when dependencies are already installed |
| `./install.sh --dry-run` | Simulate the process without changing files or system state |
| `./install.sh --yes --dry-run --no-packages` | Non-interactive simulation without package or service actions |
| `./install.sh --update` | Pull the latest repository changes, then run the installer |
| `./install.sh --help` | Show available options |

**Safety notes:**
- Do not run the installer with `sudo`; it invokes privileged commands only when needed.
- `--yes` accepts prompts, including package installation and enabling NetworkManager. Use `--dry-run` to preview first.
- `--no-packages` skips pacman but does not verify that every dependency is installed.
- `--dry-run` does not pull Git changes, install packages, write files, create backups, or enable services.
- Replacements are backed up under `~/.config/moonforge/backups/` (or the corresponding `XDG_CONFIG_HOME`).
- The installer currently supports Arch Linux only. The `awww` wallpaper daemon is optional and may need separate installation.

## 2. Requirements

- Arch Linux
- A working Hyprland session
- An active user session with a valid Wayland environment
- Internet access to install packages and clone the repository

The current configuration uses these components:

| Package / component | Purpose |
|---|---|
| `hyprland` | Wayland compositor |
| `quickshell` | Desktop bar, audio controls, network status, and tray menus |
| `fuzzel` | Application launcher |
| `kitty` | Terminal |
| `dolphin` | File manager |
| `networkmanager` | Network status queried by the Quickshell bar |
| `pipewire` and `wireplumber` | Audio services used by the audio controls |
| `hyprpolkitagent` | Authentication agent |
| `papirus-icon-theme` | Launcher icon theme |
| `awww` | Wallpaper daemon (optional, installed separately if not available in your configured repositories) |

## 3. Install packages

Install the main packages from the official repositories:

```bash
sudo pacman -S --needed git hyprland quickshell fuzzel kitty dolphin networkmanager pipewire wireplumber hyprpolkitagent papirus-icon-theme
```

Audio support depends on the PipeWire packages and services already configured on your system. If PipeWire is not yet set up, follow the current Arch Linux documentation for PipeWire before continuing. Avoid installing a second, conflicting audio server over an existing working setup.

### Wallpaper daemon

Moonforge uses `awww` for wallpaper management. It may need to be installed separately depending on your enabled repositories and package source. If using an AUR helper, inspect the package and build information before installing it.

## 4. Clone the repository

Clone the repository to a convenient location. The commands below use `~/Projects/moonforged-rice` as an example; the running configuration will not depend on that clone location:

```bash
mkdir -p ~/Projects
git clone https://github.com/WhiteF0xx/moonforged-rice.git ~/Projects/moonforged-rice
cd ~/Projects/moonforged-rice
```

You can keep the repository elsewhere; the wallpaper is copied into your user configuration directory in a later step.

## 5. Portable defaults and optional customization

Moonforge now uses generic defaults where possible:

- **Monitor:** Hyprland uses the preferred mode and automatic placement for connected monitors. Add explicit monitor rules only if you need custom resolution, refresh rate, position, or scaling. Run `hyprctl monitors` to inspect displays.
- **Network:** Quickshell detects connected devices by NetworkManager device type (`ethernet` or `wifi`), not by interface name. Make sure NetworkManager is running.
- **Fuzzel:** The shell and Hyprland launch `fuzzel` without an absolute config path. Fuzzel reads its standard user config at `~/.config/fuzzel/fuzzel.ini`.
- **Wallpaper:** The startup command reads `~/.config/moonforge/wallpaper.jpg`, independent of where you cloned the repository.
- **Home directory:** No username-specific home path is embedded in the Quickshell launcher.

You can still customize monitor rules and other settings for your hardware after installation.

## 6. Back up existing configuration

Do not overwrite existing configuration files without a backup. The following example creates timestamped copies of the files that are about to be replaced:

```bash
stamp=$(date +%Y%m%d-%H%M%S)

for file in \
  ~/.config/hypr/hyprland.conf \
  ~/.config/quickshell/shell.qml \
  ~/.config/quickshell/shell/components/NetworkPopup.qml \
  ~/.config/fuzzel/fuzzel.ini \
  ~/.config/kitty/kitty.conf
do
  if [ -f "$file" ]; then
    cp -a "$file" "$file.backup-$stamp"
  fi
done
```

This backs up those individual files only. If you have additional Hyprland, Quickshell, Fuzzel, or Kitty configuration files, back those up separately as well.

## 7. Apply the configurations

Create the target directories:

```bash
mkdir -p ~/.config/hypr ~/.config/quickshell ~/.config/quickshell/shell/components ~/.config/fuzzel ~/.config/moonforge ~/.config/kitty
```

Copy the project files:

```bash
cp ~/Projects/moonforged-rice/hypr/hyprland.conf ~/.config/hypr/hyprland.conf
cp ~/Projects/moonforged-rice/quickshell/shell/shell.qml ~/.config/quickshell/shell.qml
cp ~/Projects/moonforged-rice/quickshell/shell/components/NetworkPopup.qml ~/.config/quickshell/shell/components/NetworkPopup.qml
cp ~/Projects/moonforged-rice/fuzzel/moonforge.ini ~/.config/fuzzel/fuzzel.ini
cp ~/Projects/moonforged-rice/wallpapers/moonforge_wallpaper.jpg ~/.config/moonforge/wallpaper.jpg
cp ~/Projects/moonforged-rice/kitty/moonforge.conf ~/.config/kitty/moonforge.conf
```

**Hyprland warning:** If you already have a working Hyprland configuration, do not blindly replace it with the sample file. Merge the settings and keybindings you want into your existing configuration instead. The sample includes monitor settings, keybindings, startup commands, and other compositor preferences.

### Enable the Kitty theme

Open `~/.config/kitty/kitty.conf` and add:

```conf
include moonforge.conf
```

If you do not already have a `kitty.conf`, create one with that line.

## 8. Start required services and test

Make sure NetworkManager is enabled if you use it:

```bash
sudo systemctl enable --now NetworkManager
```

Confirm that your audio services are running if you use PipeWire:

```bash
systemctl --user status pipewire wireplumber
```

From inside your Hyprland session, test the shell manually:

```bash
qs
```

If the bar appears, test the launcher, audio popup, network popup, and tray menus. Check the terminal output for errors. Do not add automatic startup until the manual test succeeds.

To start Quickshell automatically after it has been tested, add this to your Hyprland configuration:

```ini
exec-once = qs
```

If you use the included wallpaper startup commands, ensure `awww` is installed and that the wallpaper path is correct. You can test the daemon and wallpaper manually:

```bash
awww-daemon
awww img ~/.config/moonforge/wallpaper.jpg
```

Avoid starting a second daemon if one is already running.

## 9. Useful keybindings

The sample Hyprland configuration currently defines:

| Shortcut | Action |
|---|---|
| `Super + Enter` | Open Kitty |
| `Super + Q` | Close active window |
| `Super + M` | Exit Hyprland |
| `Super + V` | Toggle floating |
| `Super + F` | Toggle fullscreen |
| `Super + Space` | Open Fuzzel |
| `Super + Shift + S` | Launch Flameshot (if installed) |
| `Super + 1–5` | Switch workspace |
| `Super + Shift + 1–5` | Move active window to workspace |

These are the defaults in the repository configuration; edit them to suit your workflow. Flameshot is optional and is not included in the main package list.

## 10. Troubleshooting

### Quickshell bar does not appear

Run `qs` from a terminal inside the Hyprland session and read the error output. Confirm that the configuration is at `~/.config/quickshell/shell.qml` and that Quickshell is installed.

### Network status shows disconnected

Run `nmcli device status` and make sure NetworkManager is running. The bar detects connected Ethernet and Wi-Fi devices by their NetworkManager device type.

### Audio controls show no device

Check that PipeWire and WirePlumber are running in the user session and that an audio sink is available.

### Wallpaper does not load

Confirm that `awww-daemon` is running and that `~/.config/moonforge/wallpaper.jpg` exists.

### Fuzzel does not open

Run `fuzzel` from a terminal. Check that `~/.config/fuzzel/fuzzel.ini` exists and that the configured icon theme is installed.

## 11. Updating Moonforge

From the repository directory:

```bash
cd ~/Projects/moonforged-rice
git pull
```

Review changed files before copying updates into `~/.config/`. Keep your backups until you have confirmed that the updated configuration works.

---

Moonforge is evolving. Package versions, configuration syntax, and hardware-specific settings may change. Always review the current repository files and adapt them to your system before applying them.
