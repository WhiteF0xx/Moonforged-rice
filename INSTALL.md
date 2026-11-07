# Moonforge Installation Guide

Moonforge is a personal Arch Linux / Hyprland configuration project. These instructions describe how to apply the current configuration on a fresh Arch Linux installation.

> **Important:** This is a work in progress, not a universal one-click installer. Review the configuration and adapt machine-specific settings before applying it. Back up existing files first. The Hyprland configuration in this repository is intended as a starting point and can replace existing keybindings and settings if copied over an existing setup.

## 1. Requirements

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

## 2. Install packages

Install the main packages from the official repositories:

```bash
sudo pacman -S --needed git hyprland quickshell fuzzel kitty dolphin networkmanager pipewire wireplumber hyprpolkitagent papirus-icon-theme
```

Audio support depends on the PipeWire packages and services already configured on your system. If PipeWire is not yet set up, follow the current Arch Linux documentation for PipeWire before continuing. Avoid installing a second, conflicting audio server over an existing working setup.

### Wallpaper daemon

Moonforge uses `awww` for wallpaper management. It may need to be installed separately depending on your enabled repositories and package source. If using an AUR helper, inspect the package and build information before installing it.

## 3. Clone the repository

The current Hyprland wallpaper command expects the repository at `~/Projects/moonforged-rice`. Clone it there to match the default path:

```bash
mkdir -p ~/Projects
git clone https://github.com/WhiteF0xx/moonforged-rice.git ~/Projects/moonforged-rice
cd ~/Projects/moonforged-rice
```

If you choose another location, update the wallpaper path in `hypr/hyprland.conf` before using it.

## 4. Review machine-specific settings

Do this before copying the Hyprland or Quickshell files.

### Monitor

The sample Hyprland config contains a monitor rule for:

```ini
monitor = DP-1, 2560x1440@164.83, 0x0, 1
```

Check your actual monitor name and supported modes:

```bash
hyprctl monitors
```

Edit `hypr/hyprland.conf` to match your display. If you are unsure, use Hyprland's automatic monitor configuration instead of copying the example rule unchanged.

### Network interface names

The Quickshell network status code currently checks the interface names `enp4s0` and `wlp10s0f3u1i2`. These names are specific to the development machine.

Find your own interface names:

```bash
nmcli device status
```

Open `quickshell/shell/shell.qml` and replace those two interface names in the network status process with the names shown on your system. If you only use Ethernet or only Wi-Fi, adjust the logic accordingly.

### User-specific paths

The Quickshell file currently contains an absolute path under `/home/WhiteFox/.config/moonforge/` for the Fuzzel configuration. Replace `/home/WhiteFox` with your actual home directory in `quickshell/shell/shell.qml`.

The Hyprland config also refers to the wallpaper inside `~/Projects/moonforged-rice`. If the repository is stored elsewhere, update that path.

## 5. Back up existing configuration

Do not overwrite existing configuration files without a backup. The following example creates timestamped copies of the files that are about to be replaced:

```bash
stamp=$(date +%Y%m%d-%H%M%S)

for file in \
  ~/.config/hypr/hyprland.conf \
  ~/.config/quickshell/shell.qml \
  ~/.config/moonforge/fuzzel.ini \
  ~/.config/kitty/kitty.conf
do
  if [ -f "$file" ]; then
    cp -a "$file" "$file.backup-$stamp"
  fi
done
```

This backs up those individual files only. If you have additional Hyprland, Quickshell, Fuzzel, or Kitty configuration files, back those up separately as well.

## 6. Apply the configurations

Create the target directories:

```bash
mkdir -p ~/.config/hypr ~/.config/quickshell ~/.config/moonforge ~/.config/kitty
```

Copy the project files:

```bash
cp ~/Projects/moonforged-rice/hypr/hyprland.conf ~/.config/hypr/hyprland.conf
cp ~/Projects/moonforged-rice/quickshell/shell/shell.qml ~/.config/quickshell/shell.qml
cp ~/Projects/moonforged-rice/fuzzel/moonforge.ini ~/.config/moonforge/fuzzel.ini
cp ~/Projects/moonforged-rice/kitty/moonforge.conf ~/.config/kitty/moonforge.conf
```

**Hyprland warning:** If you already have a working Hyprland configuration, do not blindly replace it with the sample file. Merge the settings and keybindings you want into your existing configuration instead. The sample includes monitor settings, keybindings, startup commands, and other compositor preferences.

### Enable the Kitty theme

Open `~/.config/kitty/kitty.conf` and add:

```conf
include moonforge.conf
```

If you do not already have a `kitty.conf`, create one with that line.

## 7. Start required services and test

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
awww img ~/Projects/moonforged-rice/wallpapers/moonforge_wallpaper.jpg
```

Avoid starting a second daemon if one is already running.

## 8. Useful keybindings

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

## 9. Troubleshooting

### Quickshell bar does not appear

Run `qs` from a terminal inside the Hyprland session and read the error output. Confirm that the configuration is at `~/.config/quickshell/shell.qml` and that Quickshell is installed.

### Network status shows disconnected

Run `nmcli device status` and compare the interface names with those in `shell.qml`. Make sure NetworkManager is running.

### Audio controls show no device

Check that PipeWire and WirePlumber are running in the user session and that an audio sink is available.

### Wallpaper does not load

Confirm that `awww-daemon` is running and that the image path in the Hyprland config points to the wallpaper file in this repository.

### Fuzzel does not open

Run `fuzzel --config ~/.config/moonforge/fuzzel.ini` from a terminal. Check that the file exists at that exact path and that the configured icon theme is installed.

## 10. Updating Moonforge

From the repository directory:

```bash
cd ~/Projects/moonforged-rice
git pull
```

Review changed files before copying updates into `~/.config/`. Keep your backups until you have confirmed that the updated configuration works.

---

Moonforge is evolving. Package versions, configuration syntax, and hardware-specific settings may change. Always review the current repository files and adapt them to your system before applying them.
