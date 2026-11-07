# Changelog

All notable Moonforge changes are documented here.

## [Unreleased]

### Added
- Arch Linux installer with interactive and non-interactive modes.
- `--update` option to fast-forward the local Git checkout before installation.
- `--yes` option for automated confirmations.
- `--no-packages` option for systems where dependencies are already installed.
- `--dry-run` option to preview file operations without changing files or system state.
- Installation summary listing installed, updated, skipped, and backed-up files.

### Safety
- Existing Hyprland configuration is protected and never overwritten by the installer.
- Existing files are backed up before replacement.
- Kitty theme include is added without duplicating an existing include.

### Documentation
- Added installer usage, options, and safety notes to the installation guide.
- Updated README roadmap and project status.
