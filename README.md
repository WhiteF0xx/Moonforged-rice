# ☾ Moonforge

**An Arch Linux desktop, forged after dark.**

Moonforge is an Arch Linux dotfiles project built incrementally around Hyprland, Quickshell, and a carefully tuned keyboard-driven workflow.

The goal is a cohesive, lightweight desktop that remains understandable, maintainable, and easy to reproduce.

## ✦ The stack

| Component | Purpose |
|---|---|
| Arch Linux | Operating system |
| Hyprland | Wayland compositor |
| Quickshell | Custom desktop shell and status bar |
| Fuzzel | Application launcher |
| Kitty | Terminal emulator |
| awww | Wallpaper management |
| Dolphin | File manager |

## ◈ Design language

Moonforge uses a moonlit, Catppuccin Mocha-inspired palette, with soft blue and lavender accents, restrained animations, and a minimal layout.

- Background: `#1e1e2e`
- Surface: `#313244`
- Blue accent: `#89b4fa`
- Lavender accent: `#cba6f7`
- Main text: `#cdd6f4`

## 📁 Repository layout

- `hypr/` — Hyprland configuration
- `quickshell/` — custom shell and bar
- `fuzzel/` — application launcher theme
- `kitty/` — terminal color theme
- `wallpapers/` — Moonforge wallpaper

## 🚀 Installation status

Moonforge is a work in progress. Its components are being configured and tested individually.

The current setup includes:

- Hyprland keyboard bindings and window layout settings
- Quickshell desktop bar
- Fuzzel launcher theme, bound to `Super + Space`
- Kitty color theme
- `awww` wallpaper configuration

### Applying configurations

**Back up existing configuration files before replacing them.** The files in this repository are tailored to the current setup and may need adjustment on another machine.

The configuration files are maintained in the repository separately from their active copies under `~/.config/`. Copy or link them into place only after reviewing the relevant settings.

The wallpaper is currently stored in `wallpapers/moonforge_wallpaper.jpg`.

## 🛡️ Philosophy

- Preserve a working desktop while experimenting.
- Prefer native packages and lightweight tools.
- Keep configurations readable and version-controlled.
- Document changes and installation steps.
- Never commit credentials, private keys, or personal data.
- Avoid interfering with other desktop environments, including KDE Plasma.

## 🚧 Project status

**Work in progress.** Installation automation and additional desktop components will be documented as they become stable.

---

*Forged in the dark. Built one commit at a time.*