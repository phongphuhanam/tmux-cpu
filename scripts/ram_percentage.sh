#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

ram_percentage_format="%3.1f%%"

sum_macos_vm_stats() {
  grep -Eo '[0-9]+' |
    awk '{ a += $1 * 4096 } END { print a }'
}

print_ram_percentage() {
  ram_percentage_format=$(get_tmux_option "@ram_percentage_format" "$ram_percentage_format")

  if is_jetson; then
    # Jetson has unified memory - RAM already reflects both CPU and GPU use.
    jetson_stat ram_pct | awk -v format="$ram_percentage_format" '{printf format, $1}'
  elif is_apple_silicon && command_exists "macmon"; then
    # Reuses the same cached macmon call as the temp/power stats instead of
    # spawning a separate vm_stat.
    local json used total
    json="$(macmon_json)"
    used="$(echo "$json" | grep -Eo '"ram_usage":[0-9]+' | grep -Eo '[0-9]+$')"
    total="$(echo "$json" | grep -Eo '"ram_total":[0-9]+' | grep -Eo '[0-9]+$')"
    echo "$used $total" | awk -v format="$ram_percentage_format" '{printf format, 100*$1/$2}'
  elif command_exists "free"; then
    cached_eval free | awk -v format="$ram_percentage_format" '$1 ~ /Mem/ {printf(format, 100*$3/$2)}'
  elif command_exists "vm_stat"; then
    # page size of 4096 bytes
    stats="$(cached_eval vm_stat)"

    used_and_cached=$(
      echo "$stats" |
        grep -E "(Pages active|Pages inactive|Pages speculative|Pages wired down|Pages occupied by compressor)" |
        sum_macos_vm_stats
    )

    cached=$(
      echo "$stats" |
        grep -E "(Pages purgeable|File-backed pages)" |
        sum_macos_vm_stats
    )

    free=$(
      echo "$stats" |
        grep -E "(Pages free)" |
        sum_macos_vm_stats
    )

    used=$((used_and_cached - cached))
    total=$((used_and_cached + free))

    echo "$used $total" | awk -v format="$ram_percentage_format" '{printf(format, 100*$1/$2)}'
  fi
}

main() {
  print_ram_percentage
}
main
