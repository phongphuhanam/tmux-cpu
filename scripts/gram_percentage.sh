#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

gram_percentage_format="%3.1f%%"

print_gram_percentage() {
  gram_percentage_format=$(get_tmux_option "@gram_percentage_format" "$gram_percentage_format")

  if command_exists "nvidia-smi"; then
    loads=$(cached_eval nvidia-smi | sed -nr 's/.*\s([0-9]+)MiB\s*\/\s*([0-9]+)MiB.*/\1 \2/p')
  elif command_exists "cuda-smi"; then
    loads=$(cached_eval cuda-smi | sed -nr 's/.*\s([0-9.]+) of ([0-9.]+) MB.*/\1 \2/p' | awk '{print $2-$1" "$2}')
  elif is_apple_silicon && command_exists "ioreg"; then
    # Apple Silicon has no dedicated VRAM: GPU and CPU share one pool of
    # unified memory, so "GPU RAM" here is the driver's allocated share of it.
    used=$(cached_eval ioreg -r -d 1 -c IOAccelerator | grep -Eo '"In use system memory"=[0-9]+' | grep -Eo '[0-9]+$' | awk '{sum+=$1} END {print sum}')
    total=$(sysctl -n hw.memsize)
    loads="$used $total"
  else
    echo "No GPU"
    return
  fi
  echo "$loads" | awk -v format="$gram_percentage_format" '{used+=$1; tot+=$2} END {printf format, 100*used/tot}'
}

main() {
  print_gram_percentage
}
main "$@"
