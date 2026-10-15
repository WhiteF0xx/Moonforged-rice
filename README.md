# ☾ Moonforge

**An Arch Linux desktop, forged after dark.**

Moonforge is an Arch Linux dotfiles project built incrementally around Hyprland, Quickshell, and a carefully tuned keyboard-driven workflow.

The goal is a cohesive, lightweight desktop that feels personal without becoming difficult to understand, maintain, or reproduce.

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

Moonforge uses a moonlit, Catppuccin Mocha-inspired palette, with soft blue and lavender accents, rounded surfaces, and restrained visual effects.

| Color | Hex |
|---|---|
| Background | `#1e1e2e` |
| Surface | `#313244` |
| Hover | `#45475a` |
| Blue accent | `#89b4fa` |
| Lavender accent | `#cba6f7` |
| Main text | `#cdd6f4` |

## ✨ Current features

- **Hyprland** — window layout settings and keyboard bindings.
- **Quickshell bar** — launcher, workspace buttons, active-window title, system tray, and clock.
- **Audio controls** — volume indicator, wheel-based volume adjustment, and a custom volume popup.
- **Network controls** — connection status and a popup for network actions.
- **Custom tray menus** — themed popup menus positioned relative to their tray icons.
- **Fuzzel** — themed application launcher, bound to `Super + Space`.
- **Kitty** — Moonforge terminal color theme.
- **awww** — wallpaper setup using the Moonforge wallpaper.

This project is being built and tested on a personal Arch Linux installation. Some details may be specific to that setup, and the configuration is still evolving.

## 📁 Repository layout

```text
.
├── hypr/       # Hyprland configuration
├── quickshell/ # Custom shell, bar, and popups
├── fuzzel/     # Application launcher theme
├── kitty/      # Terminal color theme
└── wallpapers/ # Moonforge wallpaper
```

## 🛠️ Applying configurations

**Back up your existing configuration files before replacing them.**

The files in this repository are maintained separately from their active copies under `~/.config/`. Review each file and copy or link it into place only when you're ready. These configurations are tailored to the current setup and may need adjustments on another machine.

The wallpaper is stored in `wallpapers/moonforge_wallpaper.jpg`.

There is not yet a fully automated installation process; setup steps and dependencies will be documented as the project becomes more stable.

## 🗺️ Roadmap

Planned additions and improvements, in no particular order:

- [ ] Refine the Quickshell bar layout, animations, and responsive behavior.
- [ ] Improve theme consistency across Fuzzel, Kitty, notifications, icons, and other desktop components.
- [ ] Make wallpaper setup and startup more reliable.
- [ ] Add screenshots and clearer setup documentation.
- [ ] Create installation scripts with dependency checks.
- [ ] Add safe backup and restore options for existing configurations.
- [ ] Document keybindings, customization points, and troubleshooting steps.
- [ ] Explore further desktop polish and optional quality-of-life widgets.

The roadmap is a living list; items may change as the desktop develops.

## 🛡️ Philosophy

- Preserve a working desktop while experimenting.
- Prefer native packages and lightweight tools.
- Keep configurations readable and version-controlled.
- Make changes incrementally and test them before moving on.
- Never commit credentials, private keys, or personal data.
- Avoid interfering with other desktop environments, including KDE Plasma.

## 🚧 Project status

**Work in progress.** Moonforge is being developed one component at a time. Features and installation instructions will be expanded as they become stable.

---

*Forged in the dark. Built one commit at a time.*
