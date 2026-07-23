#!/usr/bin/env bash
#
# Right-click handler for the Waybar modules: show a tool in a floating
# window. Repeated clicks focus the window that is already open instead of
# stacking duplicates.
#
# Two modes, because a GUI app must not be wrapped in a terminal:
#
#   popup.sh btop                       TUI  -> alacritty --class waybar-popup
#   popup.sh --gui <class> pavucontrol  GUI  -> run it directly
#
# In GUI mode <class> is the app's own Wayland app_id, used both to find an
# already-open window and to key the hyprland.conf float/size/center rules.
# For TUI mode that class is "waybar-popup"; keep it in sync with
# hyprland.conf.

set -euo pipefail

TUI_CLASS="waybar-popup"

usage() {
  echo "uso: $(basename "$0") <comando> [args...]" >&2
  echo "     $(basename "$0") --gui <class> <comando> [args...]" >&2
  exit 1
}

# Focus an open window of the given class. Returns 1 if there is none.
# jq is not installed on this system, so match the raw JSON line.
focus_existing() {
  local class=$1
  if hyprctl clients -j | grep -q "\"class\": \"${class}\""; then
    hyprctl dispatch focuswindow "class:^${class}$"
    return 0
  fi
  return 1
}

[ $# -ge 1 ] || usage

if [ "$1" = "--gui" ]; then
  [ $# -ge 3 ] || usage
  gui_class=$2
  shift 2
  focus_existing "$gui_class" && exit 0
  exec "$@"
fi

focus_existing "$TUI_CLASS" && exit 0
exec alacritty --class "$TUI_CLASS" -e "$@"
