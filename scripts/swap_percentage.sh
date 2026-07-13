#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

swap_percentage_format="%3.1f%%"

print_swap_percentage() {
  swap_percentage_format=$(get_tmux_option "@swap_percentage_format" "$swap_percentage_format")

  if is_apple_silicon && command_exists "macmon"; then
    # Reuses the same cached macmon call as the temp/power/ram stats.
    local json used total
    json="$(macmon_json)"
    used="$(echo "$json" | grep -Eo '"swap_usage":[0-9]+' | grep -Eo '[0-9]+$')"
    total="$(echo "$json" | grep -Eo '"swap_total":[0-9]+' | grep -Eo '[0-9]+$')"
    echo "${used:-0} ${total:-0}" | awk -v format="$swap_percentage_format" '{printf format, ($2>0 ? 100*$1/$2 : 0)}'
  elif is_osx && command_exists "sysctl"; then
    cached_eval sysctl vm.swapusage |
      awk -v format="$swap_percentage_format" '{
        for (i=1;i<=NF;i++) {
          if ($i=="total") { v=$(i+2); gsub(/M/,"",v); total=v }
          if ($i=="used")  { v=$(i+2); gsub(/M/,"",v); used=v }
        }
        printf format, (total>0 ? 100*used/total : 0)
      }'
  elif command_exists "free"; then
    cached_eval free | awk -v format="$swap_percentage_format" '$1 ~ /Swap/ {printf(format, ($2>0 ? 100*$3/$2 : 0))}'
  fi
}

main() {
  print_swap_percentage
}
main
