{ config, pkgs, ... }:

{
  # Create symlinks for dotfiles in user's home directory
  # This runs after system activation
  system.userActivationScripts.linkDotfiles = ''
    # Base paths
    DOTFILES="/home/alan/nixos-config/dotfiles"
    CONFIG_DIR="/home/alan/.config"

    # Ensure .config directory exists
    mkdir -p "$CONFIG_DIR"

    # Function to create symlink
    link_config() {
      local name=$1
      local target="$DOTFILES/$name"
      local link="$CONFIG_DIR/$name"

      if [ -e "$target" ]; then
        # Remove existing file/link if it exists
        if [ -L "$link" ] || [ -e "$link" ]; then
          rm -rf "$link"
        fi
        # Create new symlink
        ln -sf "$target" "$link"
        echo "Linked: $name"
      fi
    }

    # Link all dotfile directories
    link_config "hypr"
    link_config "waybar"
    link_config "alacritty"
    link_config "btop"
    link_config "doom"
    link_config "emacs"
    link_config "gtk-3.0"
    link_config "gtk-4.0"
    link_config "rofi"
  '';
}
