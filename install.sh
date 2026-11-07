#!/usr/bin/env bash
#
# Moonforge installer
# Run from the cloned repository: ./install.sh
#
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$HOME/.config/moonforge/backups/$(date +%Y%m%d-%H%M%S)"

PACKAGES=(
    git
    hyprland
    quickshell
    fuzzel
    kitty
    dolphin
    networkmanager
    pipewire
    wireplumber
    hyprpolkitagent
    papirus-icon-theme
)

info()  { printf '\n[Moonforge] %s\n' "$*"; }
warn()  { printf '[Warning] %s\n' "$*" >&2; }
error() { printf '[Error] %s\n' "$*" >&2; exit 1; }

ask() {
    local answer
    read -r -p "$1 [y/N] " answer
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

backup_file() {
    local target="$1"
    mkdir -p "$BACKUP_DIR"
    cp -a -- "$target" "$BACKUP_DIR/"
    info "Backed up $target to $BACKUP_DIR/"
}

install_file() {
    local source="$1"
    local target="$2"

    [[ -f "$source" ]] || error "Repository file not found: $source"
    mkdir -p "$(dirname -- "$target")"

    if [[ -e "$target" ]]; then
        if ! ask "Replace $target?"; then
            warn "Skipped $target"
            return 1
        fi
        backup_file "$target"
    fi

    install -Dm644 -- "$source" "$target"
    info "Installed $target"
}

[[ -f /etc/arch-release ]] || error "Moonforge's installer currently supports Arch Linux only."
[[ "$EUID" -ne 0 ]] || error "Do not run this installer with sudo. Run it as your normal user."

for command in pacman; do
    command -v "$command" >/dev/null 2>&1 || error "Required command not found: $command"
done

info "Repository: $REPO_DIR"
info "Configuration directory: $CONFIG_DIR"

if ask "Install/check the required official Arch packages with pacman?"; then
    sudo pacman -S --needed "${PACKAGES[@]}" || error "Package installation failed."
else
    warn "Skipped package installation. Make sure the required packages are already installed."
fi

# Hyprland: never replace an existing main configuration automatically.
HYPR_TARGET="$CONFIG_DIR/hypr/hyprland.conf"
if [[ -e "$HYPR_TARGET" ]]; then
    warn "Existing Hyprland configuration detected; it will not be overwritten."
    info "Review the sample at $REPO_DIR/hypr/hyprland.conf and merge settings manually."
else
    install_file "$REPO_DIR/hypr/hyprland.conf" "$HYPR_TARGET" || true
    if [[ -f "$HYPR_TARGET" ]] && ! grep -Eq '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*qs([[:space:]]|$)' "$HYPR_TARGET"; then
        printf '\n# Moonforge desktop shell\nexec-once = qs\n' >> "$HYPR_TARGET"
    fi
fi

install_file "$REPO_DIR/quickshell/shell/shell.qml" "$CONFIG_DIR/quickshell/shell.qml" || true
install_file "$REPO_DIR/fuzzel/moonforge.ini" "$CONFIG_DIR/fuzzel/fuzzel.ini" || true
install_file "$REPO_DIR/wallpapers/moonforge_wallpaper.jpg" "$CONFIG_DIR/moonforge/wallpaper.jpg" || true
install_file "$REPO_DIR/kitty/moonforge.conf" "$CONFIG_DIR/kitty/moonforge.conf" || true

# Add the Kitty theme include without duplicating it.
KITTY_CONF="$CONFIG_DIR/kitty/kitty.conf"
mkdir -p "$(dirname -- "$KITTY_CONF")"
if [[ ! -e "$KITTY_CONF" ]]; then
    printf 'include moonforge.conf\n' > "$KITTY_CONF"
    info "Created $KITTY_CONF with the Moonforge theme include."
elif ! grep -Fxq 'include moonforge.conf' "$KITTY_CONF"; then
    if ask "Add 'include moonforge.conf' to your existing Kitty configuration?"; then
        backup_file "$KITTY_CONF"
        printf '\n# Moonforge theme\ninclude moonforge.conf\n' >> "$KITTY_CONF"
        info "Added the Moonforge theme include."
    else
        warn "Kitty theme file is installed, but it is not enabled in kitty.conf."
    fi
fi

if command -v systemctl >/dev/null 2>&1 && ask "Enable NetworkManager now?"; then
    sudo systemctl enable --now NetworkManager || warn "Could not enable NetworkManager."
fi

info "Installation steps finished."
printf '\nNext steps:\n'
printf '  1. Start or restart Quickshell with: qs\n'
printf '  2. Check the Hyprland configuration and log out/in if you installed it for the first time.\n'
printf '  3. The wallpaper daemon awww is optional and must be installed separately if unavailable in your repositories.\n'
printf '  4. If you already had a Hyprland config, merge the sample settings manually; it was left untouched.\n'

if [[ -d "$BACKUP_DIR" ]]; then
    info "Backups are stored in: $BACKUP_DIR"
fi
