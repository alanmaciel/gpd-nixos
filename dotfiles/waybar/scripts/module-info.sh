#!/usr/bin/env bash
#
# Left-click handler for the Waybar modules.
#
# The bar is icon-only, so on the GPD's 1024x576 logical screen there is no
# room to print numbers and hovering for a tooltip with the nub is fiddly.
# This pops the actual values as a mako notification instead.
#
# Right-click opens the full TUI instead; see popup.sh.
#
# Usage: module-info.sh <cpu|memory|temperature|battery|network|volume>

set -euo pipefail

notify() {
  notify-send -a waybar -t 6000 "$1" "$2"
}

# Total and idle jiffies from the aggregate "cpu" line of /proc/stat.
# Waybar's own computed usage is not exposed to scripts, so we resample.
cpu_sample() {
  local line vals total=0 i
  read -r line < /proc/stat
  read -ra vals <<< "$line"
  for ((i = 1; i < ${#vals[@]}; i++)); do
    total=$((total + vals[i]))
  done
  # vals[4] = idle, vals[5] = iowait
  echo "$total $((vals[4] + vals[5]))"
}

cpu_usage() {
  local t1 i1 t2 i2 dt di
  read -r t1 i1 < <(cpu_sample)
  sleep 0.25
  read -r t2 i2 < <(cpu_sample)
  dt=$((t2 - t1))
  di=$((i2 - i1))
  if ((dt <= 0)); then
    echo 0
  else
    echo $(((100 * (dt - di)) / dt))
  fi
}

info_cpu() {
  local usage load freq cores
  usage=$(cpu_usage)
  read -r load _ < /proc/loadavg
  cores=$(nproc)
  # cpuinfo reports MHz per core; average them for a single readable figure.
  freq=$(awk '/^cpu MHz/ {s += $4; n++} END {if (n) printf "%.1f", s / n / 1000}' /proc/cpuinfo)
  notify "CPU" "Uso: ${usage}%
Carga: ${load} (${cores} núcleos)
Frecuencia: ${freq} GHz"
}

info_memory() {
  awk '
    /^MemTotal:/     { total = $2 }
    /^MemAvailable:/ { avail = $2 }
    /^SwapTotal:/    { swtot = $2 }
    /^SwapFree:/     { swfree = $2 }
    END {
      used = total - avail
      printf "Usada: %.1f GiB de %.1f GiB (%d%%)\n", used/1048576, total/1048576, used*100/total
      printf "Disponible: %.1f GiB\n", avail/1048576
      if (swtot > 0)
        printf "Swap: %.1f GiB de %.1f GiB", (swtot-swfree)/1048576, swtot/1048576
      else
        printf "Swap: no configurada"
    }
  ' /proc/meminfo | { mapfile -t out; notify "RAM" "$(printf '%s\n' "${out[@]}")"; }
}

info_temperature() {
  local dir body
  # hwmonN numbering is not stable across boots, so glob from the device path
  # (same reason the waybar config uses hwmon-path-abs).
  dir=$(echo /sys/devices/platform/coretemp.0/hwmon/hwmon*)
  body=$(
    for input in "$dir"/temp*_input; do
      [ -e "$input" ] || continue
      label=$(cat "${input%_input}_label" 2>/dev/null || basename "$input")
      printf '%s: %d °C\n' "$label" "$(($(cat "$input") / 1000))"
    done
  )
  notify "Temperatura" "${body%$'\n'}"
}

info_battery() {
  local bat=/sys/class/power_supply/BAT0
  local cap status power energy body extra=""
  cap=$(cat "$bat/capacity")
  status=$(cat "$bat/status")

  # energy_* on some kernels, charge_* on others.
  if [ -r "$bat/energy_now" ] && [ -r "$bat/power_now" ]; then
    energy=$(cat "$bat/energy_now")
    power=$(cat "$bat/power_now")
    if ((power > 0)); then
      if [ "$status" = "Discharging" ]; then
        extra=$(awk -v e="$energy" -v p="$power" \
          'BEGIN { m = e * 60 / p; printf "Restante: %dh %02dm\n", m/60, m%60 }')
      fi
      extra+=$(awk -v p="$power" 'BEGIN { printf "Consumo: %.1f W", p/1000000 }')
    fi
  fi

  body="Carga: ${cap}%
Estado: ${status}"
  [ -n "$extra" ] && body+=$'\n'"$extra"
  notify "Batería" "$body"
}

info_network() {
  local body iface
  iface=$(ip -o route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "dev") {print $(i+1); exit}}') || true

  if [ -z "${iface:-}" ]; then
    notify "Red" "Sin conexión"
    return
  fi

  body="Interfaz: ${iface}"

  # nmcli knows the SSID and signal; ip knows the address.
  local ssid signal
  ssid=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | awk -F: '$1 == "yes" {print $2; exit}') || true
  signal=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | awk -F: '$1 == "yes" {print $3; exit}') || true
  [ -n "${ssid:-}" ] && body+=$'\n'"SSID: ${ssid} (${signal}%)"

  local addr
  addr=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{print $4; exit}') || true
  [ -n "${addr:-}" ] && body+=$'\n'"IP: ${addr}"

  local gw
  gw=$(ip -o route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "via") {print $(i+1); exit}}') || true
  [ -n "${gw:-}" ] && body+=$'\n'"Gateway: ${gw}"

  notify "Red" "$body"
}

info_volume() {
  local raw vol muted sink body
  raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)   # "Volume: 0.45 [MUTED]"
  vol=$(awk '{printf "%d", $2 * 100}' <<< "$raw")
  muted="no"
  [[ "$raw" == *MUTED* ]] && muted="sí"
  sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null |
    awk -F'"' '/node.description/ {print $2; exit}') || true

  body="Volumen: ${vol}%
Silenciado: ${muted}"
  [ -n "${sink:-}" ] && body+=$'\n'"Salida: ${sink}"
  notify "Audio" "$body"
}

case "${1:-}" in
  cpu)         info_cpu ;;
  memory)      info_memory ;;
  temperature) info_temperature ;;
  battery)     info_battery ;;
  network)     info_network ;;
  volume)      info_volume ;;
  *)
    echo "uso: $(basename "$0") <cpu|memory|temperature|battery|network|volume>" >&2
    exit 1
    ;;
esac
