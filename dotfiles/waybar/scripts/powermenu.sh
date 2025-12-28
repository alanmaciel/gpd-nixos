#!/usr/bin/env bash

choice=$(printf "Logout\nReboot\nShutdown" | rofi -dmenu -p "Power" -theme-str 'window { width: 20%; }')

case "$choice" in
  Logout)
    hyprctl dispatch exit
    ;;
  Reboot)
    systemctl reboot
    ;;
  Shutdown)
    systemctl poweroff
    ;;
  *)
    exit 0
    ;;
esac
