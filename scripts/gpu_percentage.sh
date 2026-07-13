#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

gpu_percentage_format="%3.1f%%"

print_gpu_percentage() {
  gpu_percentage_format=$(get_tmux_option "@gpu_percentage_format" "$gpu_percentage_format")

  if is_jetson; then
    jetson_stat gpu_pct | awk -v format="$gpu_percentage_format" '{printf format, $1}'
  elif command_exists "nvidia-smi"; then
    loads=$(cached_eval nvidia-smi)
    echo "$loads" | sed -nr 's/.*\s([0-9]+)%.*/\1/p' | awk -v format="$gpu_percentage_format" '{sum+=$1; n+=1} END {printf format, sum/n}'
  elif command_exists "cuda-smi"; then
    loads=$(cached_eval cuda-smi)
    echo "$loads" | sed -nr 's/.*\s([0-9]+)%.*/\1/p' | awk -v format="$gpu_percentage_format" '{sum+=$1; n+=1} END {printf format, sum/n}'
  elif is_apple_silicon && command_exists "ioreg"; then
    # AGXAccelerator exposes GPU utilization via ioreg with no root needed,
    # unlike powermetrics which is the only other source on Apple Silicon.
    cached_eval ioreg -r -d 1 -c IOAccelerator |
      grep -Eo '"Device Utilization %"=[0-9]+' |
      grep -Eo '[0-9]+$' |
      awk -v format="$gpu_percentage_format" '{sum+=$1; n+=1} END {if (n>0) printf format, sum/n}'
  else
    echo "No GPU"
  fi
}

main() {
  print_gpu_percentage
}
main
