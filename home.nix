{ config, pkgs, ... }:

{
  # Create symlinks for dotfiles in user's home directory
  # This runs after system activation
  system.userActivationScripts.linkDotfiles = ''
    # userActivationScripts runs once per user (alan, root, greeter...), but
    # the paths below belong to alan. Without this guard the other users ran
    # the script and failed with permission denied on every activation.
    if [ "$(id -un)" != "alan" ]; then
      exit 0
    fi

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

      if [ ! -e "$target" ]; then
        return
      fi

      if [ -L "$link" ]; then
        # It is one of our symlinks: replacing it is safe
        rm -f "$link"
      elif [ -e "$link" ]; then
        # A real directory or file holding user data (eln-cache,
        # straight/build, etc.). Never blindly delete it with rm -rf.
        echo "Skipped: $name ($link exists and is not a symlink; move it by hand)" >&2
        return
      fi

      ln -s "$target" "$link"
      echo "Linked: $name"
    }

    # Link all dotfile directories
    link_config "hypr"
    link_config "waybar"
    link_config "mako"
    link_config "alacritty"
    link_config "btop"
    link_config "doom"
    link_config "emacs"
    link_config "gtk-3.0"
    link_config "gtk-4.0"
    link_config "rofi"
  '';
}
