#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

gpu_power_format="%.2fW"

print_gpu_power() {
  gpu_power_format=$(get_tmux_option "@gpu_power_format" "$gpu_power_format")

  if is_apple_silicon && command_exists "macmon"; then
    macmon_json |
      grep -Eo '"gpu_power":[0-9.]+' |
      grep -Eo '[0-9.]+$' |
      awk -v format="$gpu_power_format" '{printf format, $1}'
  fi
}

main() {
  print_gpu_power
}
main
