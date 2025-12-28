# NixOS Config Verification Summary

## Issues Found and Fixed

### 1. ✅ Fixed home.nix
**Problem**: home.nix was using home-manager syntax but home-manager wasn't installed. Symlinks were never created.

**Solution**: Replaced with proper NixOS activation script that creates symlinks on system rebuild.

**What it does now**:
- Automatically creates symlinks from `~/nixos-config/dotfiles/*` to `~/.config/*`
- Runs during `sudo nixos-rebuild switch`
- Links: hypr, waybar, alacritty, btop, doom, emacs, gtk-3.0, gtk-4.0, rofi

### 2. ✅ Moved alacritty config into repo
**Problem**: alacritty was a symlink pointing to `/home/alan/nixos-dotfiles/alacritty/` (outside the repo)

**Solution**: Copied actual alacritty config files into `dotfiles/alacritty/`

### 3. ✅ Removed external symlinks
**Problem**: qtile symlink pointing to external nixos-dotfiles directory

**Solution**: Removed the symlink (you already removed qtile from configuration.nix)

### 4. ✅ Removed Qtile configuration
**Problem**: Qtile window manager configs still present even though you're using Hyprland

**Solution**:
- Removed `windowManager.qtile.enable = true;`
- Removed `displayManager.sessionCommands` with xwallpaper
- Kept X11 server enabled (needed for XWayland)

### 5. ✅ Fixed hyprland wallpaper
**Problem**: hyprpaper wasn't starting automatically

**Solution**: Added `exec-once = hyprpaper` to hyprland.conf autostart section

### 6. ✅ Fixed waybar workspace colors
**Problem**: Couldn't tell which workspaces had apps

**Solution**: Added CSS styling:
- Empty workspaces: dim gray, no background
- Occupied workspaces: yellow text with gray background
- Active workspace: blue background with white text

### 7. ✅ Created .gitignore
**Problem**: Git would track large cache directories and build artifacts

**Solution**: Created .gitignore to exclude:
- `dotfiles/emacs/.local/` (Doom Emacs build artifacts - ~1GB+)
- `dotfiles/chromium/` (browser cache)
- `dotfiles/google-chrome/` (browser cache)
- `dotfiles/dconf/` (binary database files)
- Machine-specific configs (akonadi, pulse, kde, pcmanfm, etc.)
- Backup files (*.bak, *.old)

## What's Included in Git Backup

### Core NixOS Files ✅
- `configuration.nix` - Main system config
- `hardware-configuration.nix` - Hardware detection (auto-generated)
- `home.nix` - Dotfile symlink automation
- `CLAUDE.md` - Documentation for Claude Code
- `.gitignore` - Git exclusions

### Important Dotfiles ✅
- `dotfiles/hypr/` - Hyprland window manager config
- `dotfiles/waybar/` - Status bar config
- `dotfiles/alacritty/` - Terminal config
- `dotfiles/doom/` - Doom Emacs user config (init.el, config.el, packages.el)
- `dotfiles/emacs/` - Doom Emacs framework (excluding .local/ build dir)
- `dotfiles/btop/` - System monitor config
- `dotfiles/gtk-3.0/` & `dotfiles/gtk-4.0/` - GTK theme settings
- `dotfiles/rofi/` - App launcher config

### Excluded from Git ❌
- Browser caches (chromium, google-chrome)
- Doom Emacs builds (.local/)
- Binary databases (dconf, akonadi)
- Machine-specific state (pulse, kde settings, pcmanfm)

## Next Steps

### 1. Test the Configuration
```bash
sudo nixos-rebuild switch
```

This will:
- Apply configuration changes
- Create symlinks from dotfiles/ to ~/.config/
- Activate the new system

### 2. Verify Symlinks Were Created
```bash
ls -la ~/.config/ | grep " -> /home/alan/nixos-config"
```

You should see symlinks for:
- hypr → /home/alan/nixos-config/dotfiles/hypr
- waybar → /home/alan/nixos-config/dotfiles/waybar
- alacritty → /home/alan/nixos-config/dotfiles/alacritty
- doom → /home/alan/nixos-config/dotfiles/doom
- etc.

### 3. Commit to Git
```bash
cd ~/nixos-config
git add .
git commit -m "Complete NixOS config for GPD Micro PC

- Fixed home.nix to create dotfile symlinks properly
- Moved all configs into repository
- Added Hyprland, Waybar, Doom Emacs configs
- Removed Qtile (switched to Hyprland)
- Added .gitignore for caches and build artifacts
- Created CLAUDE.md documentation"

git push origin main
```

### 4. Restart to Apply Wallpaper
The hyprpaper change requires restarting Hyprland:
- Press `Super+Ctrl+Q` to exit Hyprland
- Log back in

Or run immediately:
```bash
hyprpaper &
```

## Repository Structure

```
nixos-config/
├── configuration.nix       # Main NixOS system configuration
├── hardware-configuration.nix  # Auto-generated hardware setup
├── home.nix                # Dotfile symlink automation
├── CLAUDE.md               # Claude Code documentation
├── .gitignore              # Git exclusions
└── dotfiles/               # User configuration files
    ├── hypr/               # Hyprland (window manager)
    ├── waybar/             # Waybar (status bar)
    ├── alacritty/          # Alacritty (terminal)
    ├── doom/               # Doom Emacs user config
    ├── emacs/              # Doom Emacs framework
    ├── btop/               # System monitor
    ├── gtk-3.0/            # GTK3 themes
    ├── gtk-4.0/            # GTK4 themes
    └── rofi/               # Rofi (app launcher)
```

## Backup/Restore Process

### To Backup (First Time)
```bash
cd ~/nixos-config
git init
git add .
git commit -m "Initial GPD Micro PC NixOS config"
git remote add origin <your-github-repo-url>
git push -u origin main
```

### To Restore on New Machine
```bash
git clone <your-github-repo-url> ~/nixos-config
cd ~/nixos-config
sudo cp configuration.nix /etc/nixos/
sudo cp hardware-configuration.nix /etc/nixos/  # Or regenerate with nixos-generate-config
sudo nixos-rebuild switch
```

The symlinks will be created automatically by home.nix during the rebuild.

## All Fixed! ✅

Your configuration is now:
- ✅ Self-contained in one repository
- ✅ No external dependencies or symlinks
- ✅ Properly excludes caches and build artifacts
- ✅ Automated symlink creation
- ✅ Ready to backup to GitHub
- ✅ Fully documented for future Claude instances
