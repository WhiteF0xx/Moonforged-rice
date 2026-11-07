#!/usr/bin/env bash
#
# Moonforge installer
# Run from the cloned repository: ./install.sh [--update] [--yes]
#
set -Eeuo pipefail

MODE="install"
ASSUME_YES=false
INSTALLED_FILES=()
UPDATED_FILES=()
SKIPPED_FILES=()
BACKED_UP_FILES=()

while (($#)); do
    case "$1" in
        --update)
            MODE="update"
            ;;
        --yes|-y)
            ASSUME_YES=true
            ;;
        --help|-h)
            printf 'Usage: ./install.sh [--update] [--yes]\n'
            printf '  (no option)  Install Moonforge configuration interactively.\n'
            printf '  --update     Pull the latest repository changes before installing.\n'
            printf '  --yes, -y    Automatically accept package installation, file replacements,\n'
            printf '               and enabling NetworkManager. Existing Hyprland config is\n'
            printf '               still protected and never overwritten.\n'
            printf '  --help       Show this help message.\n'
            exit 0
            ;;
        *)
            printf '[Error] Unknown option: %s\n' "$1" >&2
            printf 'Run ./install.sh --help for usage.\n' >&2
            exit 2
            ;;
    esac
    shift
done

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$CONFIG_DIR/moonforge/backups/$(date +%Y%m%d-%H%M%S)"

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
    if [[ "$ASSUME_YES" == true ]]; then
        printf '%s [auto-yes]\n' "$1"
        return 0
    fi
    read -r -p "$1 [y/N] " answer
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

backup_file() {
    local target="$1"
    mkdir -p "$BACKUP_DIR"
    cp -a -- "$target" "$BACKUP_DIR/"
    BACKED_UP_FILES+=("$target")
    info "Backed up $target to $BACKUP_DIR/"
}

install_file() {
    local source="$1"
    local target="$2"
    local existed=false

    [[ -f "$source" ]] || error "Repository file not found: $source"
    mkdir -p "$(dirname -- "$target")"

    if [[ -e "$target" ]]; then
        existed=true
        if ! ask "Replace $target?"; then
            warn "Skipped $target"
            SKIPPED_FILES+=("$target")
            return 0
        fi
        backup_file "$target"
    fi

    install -Dm644 -- "$source" "$target"
    if [[ "$existed" == true ]]; then
        UPDATED_FILES+=("$target")
        info "Updated $target"
    else
        INSTALLED_FILES+=("$target")
        info "Installed $target"
    fi
}

print_list() {
    local heading="$1"
    shift
    printf '\n%s\n' "$heading"
    if (($#)); then
        printf '  - %s\n' "$@"
    else
        printf '  (none)\n'
    fi
}

[[ -f /etc/arch-release ]] || error "Moonforge's installer currently supports Arch Linux only."
[[ "$EUID" -ne 0 ]] || error "Do not run this installer with sudo. Run it as your normal user."

for command in pacman git; do
    command -v "$command" >/dev/null 2>&1 || error "Required command not found: $command"
done

info "Repository: $REPO_DIR"
info "Configuration directory: $CONFIG_DIR"

if [[ "$MODE" == "update" ]]; then
    [[ -d "$REPO_DIR/.git" ]] || error "Update mode requires a Git clone of Moonforge."
    info "Pulling the latest Moonforge changes..."
    git -C "$REPO_DIR" pull --ff-only || error "Git update failed. Check for local changes or branch divergence, then try again."
fi

if ask "Install/check the required official Arch packages with pacman?"; then
    sudo pacman -S --needed "${PACKAGES[@]}" || error "Package installation failed."
else
    warn "Skipped package installation. Make sure the required packages are already installed."
fi

# Never replace an existing personal Hyprland configuration automatically.
HYPR_TARGET="$CONFIG_DIR/hypr/hyprland.conf"
if [[ -e "$HYPR_TARGET" ]]; then
    warn "Existing Hyprland configuration detected; it will not be overwritten."
    SKIPPED_FILES+=("$HYPR_TARGET (protected)")
    info "Review the sample at $REPO_DIR/hypr/hyprland.conf and merge settings manually."
else
    install_file "$REPO_DIR/hypr/hyprland.conf" "$HYPR_TARGET"
    if [[ -f "$HYPR_TARGET" ]] && ! grep -Eq '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*qs([[:space:]]|$)' "$HYPR_TARGET"; then
        printf '\n# Moonforge desktop shell\nexec-once = qs\n' >> "$HYPR_TARGET"
    fi
fi

install_file "$REPO_DIR/quickshell/shell/shell.qml" "$CONFIG_DIR/quickshell/shell.qml"
install_file "$REPO_DIR/fuzzel/moonforge.ini" "$CONFIG_DIR/fuzzel/fuzzel.ini"
install_file "$REPO_DIR/wallpapers/moonforge_wallpaper.jpg" "$CONFIG_DIR/moonforge/wallpaper.jpg"
install_file "$REPO_DIR/kitty/moonforge.conf" "$CONFIG_DIR/kitty/moonforge.conf"

# Add the Kitty theme include without duplicating it.
KITTY_CONF="$CONFIG_DIR/kitty/kitty.conf"
mkdir -p "$(dirname -- "$KITTY_CONF")"
if [[ ! -e "$KITTY_CONF" ]]; then
    printf 'include moonforge.conf\n' > "$KITTY_CONF"
    INSTALLED_FILES+=("$KITTY_CONF")
    info "Created $KITTY_CONF with the Moonforge theme include."
elif ! grep -Fxq 'include moonforge.conf' "$KITTY_CONF"; then
    if ask "Add 'include moonforge.conf' to your existing Kitty configuration?"; then
        backup_file "$KITTY_CONF"
        printf '\n# Moonforge theme\ninclude moonforge.conf\n' >> "$KITTY_CONF"
        UPDATED_FILES+=("$KITTY_CONF")
        info "Added the Moonforge theme include."
    else
        warn "Kitty theme include was not added."
        SKIPPED_FILES+=("$KITTY_CONF (theme include not added)")
    fi
fi

if command -v systemctl >/dev/null 2>&1; then
    if ask "Enable NetworkManager now?"; then
        if sudo systemctl enable --now NetworkManager; then
            info "NetworkManager enabled."
        else
            warn "Could not enable NetworkManager."
        fi
    else
        SKIPPED_FILES+=("NetworkManager service")
    fi
fi

if [[ "$MODE" == "update" ]]; then
    info "Moonforge update steps finished."
else
    info "Installation steps finished."
fi

printf '\n========== Moonforge summary ==========\n'
print_list "Installed:" "${INSTALLED_FILES[@]}"
print_list "Updated:" "${UPDATED_FILES[@]}"
print_list "Skipped:" "${SKIPPED_FILES[@]}"
print_list "Backed up:" "${BACKED_UP_FILES[@]}"

if [[ -d "$BACKUP_DIR" ]]; then
    info "Backups are stored in: $BACKUP_DIR"
fi

printf '\nNext steps:\n'
printf '  1. Start or restart Quickshell with: qs\n'
printf '  2. Log out and back in if this was a first-time Hyprland installation.\n'
printf '  3. Install awww separately if it is not available in your repositories.\n'
printf '  4. Existing Hyprland configuration was protected; merge the sample manually if needed.\n'
