#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

cpu_temp_format="%2.0f"
cpu_temp_unit="C"

print_cpu_temp() {
  cpu_temp_format=$(get_tmux_option "@cpu_temp_format" "$cpu_temp_format")
  cpu_temp_unit=$(get_tmux_option "@cpu_temp_unit" "$cpu_temp_unit")
  if command_exists "sensors"; then
    local val
    if [[ "$cpu_temp_unit" == F ]]; then
      val="$(sensors -f)"
    else
      val="$(sensors)"
    fi
    echo "$val" | sed -e 's/^Tccd/Core /' | awk -v format="$cpu_temp_format$cpu_temp_unit" '/^Core [0-9]+/ {gsub("[^0-9.]", "", $3); sum+=$3; n+=1} END {printf(format, sum/n)}'
  elif is_apple_silicon && command_exists "powermetrics"; then
    # Apple Silicon exposes no user-readable thermal sensor; powermetrics
    # needs root. Use non-interactive sudo so this fails silently (like the
    # no-sensors case above) unless the user added a NOPASSWD sudoers rule
    # for powermetrics.
    local temp_c
    temp_c="$(cached_eval sudo -n powermetrics -i1 -n1 --samplers smc 2>/dev/null |
      sed -n 's/^CPU die temperature: \([0-9.]*\).*/\1/p')"
    if [ -n "$temp_c" ]; then
      if [[ "$cpu_temp_unit" == F ]]; then
        echo "$temp_c" | awk -v format="$cpu_temp_format$cpu_temp_unit" '{printf(format, $1*9/5+32)}'
      else
        echo "$temp_c" | awk -v format="$cpu_temp_format$cpu_temp_unit" '{printf(format, $1)}'
      fi
    fi
  elif command_exists "vcgencmd"; then
    vcgencmd measure_temp | sed -r 's/[^0-9.]*//g'
  fi
}

main() {
  print_cpu_temp
}
main
