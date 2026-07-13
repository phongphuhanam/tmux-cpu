#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

cpu_power_format="%.2fW"

print_cpu_power() {
  cpu_power_format=$(get_tmux_option "@cpu_power_format" "$cpu_power_format")

  if is_apple_silicon && command_exists "macmon"; then
    macmon_json |
      grep -Eo '"cpu_power":[0-9.]+' |
      grep -Eo '[0-9.]+$' |
      awk -v format="$cpu_power_format" '{printf format, $1}'
  fi
}

main() {
  print_cpu_power
}
main
