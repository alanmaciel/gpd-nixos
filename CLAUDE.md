# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS configuration repository for a GPD Micro PC device. It contains declarative system and user configurations using the Nix language, including window manager setups (Hyprland + Qtile), Doom Emacs configuration, and various dotfiles.

## Architecture

### Core Configuration Files

- **configuration.nix**: Main system configuration (hardware, bootloader, services, packages, users)
- **hardware-configuration.nix**: Auto-generated hardware detection (DO NOT manually edit)
- **home.nix**: Home-manager style dotfile linking (maps `./dotfiles/*` to `~/.config/*`)

### Configuration Structure

The repository follows NixOS's declarative configuration pattern:
1. `configuration.nix` imports both `hardware-configuration.nix` and `home.nix`
2. All system-wide settings, packages, and services are defined in `configuration.nix`
3. User-level dotfiles are symlinked via `home.nix` from `./dotfiles/` to `~/.config/`
4. The actual dotfiles live in `./dotfiles/` directory (Hyprland, Waybar, Alacritty, Doom, etc.)

### Hardware-Specific Configurations

This configuration is optimized for the **GPD Micro PC**:
- Portrait display rotation: monitor configured as 720x1280 with transform,3 (270° rotation)
- GRUB text mode (`gfxmodeEfi = "text"`) to avoid graphical issues
- Intel iGPU stability kernel parameters (`i915.enable_psr=0`, `i915.enable_fbc=0`)
- Large console font (`ter-u32n`) for readability on small screen
- Custom DPI scaling (GDK_SCALE=1.10, QT_SCALE_FACTOR=1.10)
- Dual-function keys via interception-tools (/, \, Down arrow act as modifiers when held)

## Common Commands

### System Rebuilding
```bash
# Rebuild and switch to new configuration
sudo nixos-rebuild switch

# Test configuration without setting as default boot
sudo nixos-rebuild test

# Build without activating
sudo nixos-rebuild build

# Rebuild with flakes (if migrated to flakes in future)
# sudo nixos-rebuild switch --flake .#hostname
```

### Package Management
```bash
# Search for packages
nix-env -qaP | grep <package-name>

# Or use online search: https://search.nixos.org/packages

# Add packages by editing configuration.nix:
# environment.systemPackages = with pkgs; [ package-name ];
```

### Garbage Collection
```bash
# Delete old generations and free disk space
sudo nix-collect-garbage -d

# Delete generations older than 30 days
sudo nix-collect-garbage --delete-older-than 30d
```

### Dotfiles Management

Dotfiles are managed through `home.nix` which symlinks directories from `./dotfiles/` to `~/.config/`. To modify user configurations:

1. Edit files in `./dotfiles/<app-name>/`
2. Run `sudo nixos-rebuild switch` to create/update symlinks
3. Some applications may require restart to pick up changes

## Key Technologies

- **Display Server**: Wayland (via Hyprland) + X11 (via Qtile) window managers
- **Login Manager**: greetd with tuigreet (TUI greeter)
- **Audio**: PipeWire (with PulseAudio compatibility layer)
- **Editor**: Doom Emacs (extensive config in `./dotfiles/doom/` and `./dotfiles/emacs/`)
- **Terminal**: Alacritty
- **Bar**: Waybar (Wayland)
- **File Manager**: PCManFM
- **Keyboard Remapping**: interception-tools with dual-function-keys plugin

## Important Nix Patterns

### Module System
The configuration uses NixOS modules pattern where options are set using attribute sets:
```nix
services.serviceName = {
  enable = true;
  option = value;
};
```

### Package Installation
Packages are installed declaratively in `environment.systemPackages`:
```nix
environment.systemPackages = with pkgs; [
  packageName
  anotherPackage
];
```

### Service Configuration
Services are configured and enabled in `configuration.nix`:
```nix
services.openssh = {
  enable = true;
  settings = {
    PasswordAuthentication = true;
  };
};
```

## Doom Emacs Dependencies

The configuration includes comprehensive Doom Emacs support with language-specific tooling:
- LSP servers installed via nixpkgs (requires `nodejs` for many language servers)
- Build tools: gcc, clang, cmake, gnumake (for :term vterm and native compilation)
- Language toolchains: python3, ruby, nodejs
- Formatters and linters: shellcheck, html-tidy, stylelint, js-beautify, isort, pytest
- Documentation tools: pandoc (markdown), graphviz (org-mode diagrams)

## State Version

Current system.stateVersion: **24.11**

This should NOT be changed after installation as it affects system compatibility. It represents the NixOS release version at time of installation, not the current version.
