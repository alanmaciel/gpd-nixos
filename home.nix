{ config, pkgs, ... }:

{
  # Create symlinks for dotfiles in user's home directory
  # This runs after system activation
  system.userActivationScripts.linkDotfiles = ''
    # userActivationScripts corre una vez por usuario (alan, root, greeter...),
    # pero las rutas de abajo son de alan. Sin este guard los demás usuarios
    # ejecutaban el script y fallaban con permission denied en cada activación.
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
        # Es un symlink nuestro: reemplazarlo es seguro
        rm -f "$link"
      elif [ -e "$link" ]; then
        # Directorio o archivo real con datos del usuario (eln-cache,
        # straight/build, etc.). Nunca borrarlo a ciegas con rm -rf.
        echo "Skipped: $name (existe $link y no es un symlink; muévelo a mano)" >&2
        return
      fi

      ln -s "$target" "$link"
      echo "Linked: $name"
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
