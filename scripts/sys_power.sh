#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

sys_power_format="%.2fW"

print_sys_power() {
  sys_power_format=$(get_tmux_option "@sys_power_format" "$sys_power_format")

  if is_apple_silicon && command_exists "macmon"; then
    macmon_json |
      grep -Eo '"sys_power":[0-9.]+' |
      grep -Eo '[0-9.]+$' |
      awk -v format="$sys_power_format" '{printf format, $1}'
  fi
}

main() {
  print_sys_power
}
main
