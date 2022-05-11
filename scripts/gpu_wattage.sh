#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

gpu_wattage_format="%2.0f"

print_gpu_wattage() {
  gpu_wattage_format=$(get_tmux_option "@gpu_wattage_format" "$gpu_wattage_format")

  if command_exists "nvidia-smi"; then
    loads=$(cached_eval nvidia-smi | sed -nr 's/.*\s([0-9]+)W\s*\/\s*([0-9]+)W.*/\1 \2/p')
  elif command_exists "cuda-smi"; then
    loads=$(cached_eval cuda-smi | sed -nr 's/.*\s([0-9.]+) of ([0-9.]+) W.*/\1 \2/p' | awk '{print $2-$1" "$2}')
  else
    echo "No GPU"
    return
  fi
  echo "$loads" | awk -v format="${gpu_wattage_format}W" '{used+=$1; tot+=$2} END {printf format, used}'
}

main() {
  print_gpu_wattage
}
main "$@"
