#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

disk_write_format="%.1fMBs"

print_disk_write() {
  disk_write_format=$(get_tmux_option "@disk_write_format" "$disk_write_format")

  if is_osx && command_exists "ioreg"; then
    # The main physical disk's IOBlockStorageDriver is listed first; its
    # Statistics dict holds cumulative bytes since boot, diffed into a rate.
    local bytes rate
    bytes="$(cached_eval ioreg -c IOBlockStorageDriver -r -w0 | grep -m1 -Eo '"Bytes \(Write\)"=[0-9]+' | grep -Eo '[0-9]+$')"
    [ -n "$bytes" ] || return
    rate="$(rate_from_counter "disk_write" "$bytes")"
    echo "$rate" | awk -v format="$disk_write_format" '{printf format, $1/1024/1024}'
  fi
}

main() {
  print_disk_write
}
main
