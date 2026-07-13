#!/usr/bin/env bash

export LANG=C
export LC_ALL=C

get_tmux_option() {
  local option
  local default_value
  local option_value
  option="$1"
  default_value="$2"
  option_value="$(tmux show-option -qv "$option")"
  if [ -z "$option_value" ]; then
    option_value="$(tmux show-option -gqv "$option")"
  fi
  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

is_osx() {
  [ "$(uname)" == "Darwin" ]
}

is_apple_silicon() {
  is_osx && [ "$(uname -m)" == "arm64" ]
}

is_freebsd() {
  [ "$(uname)" == "FreeBSD" ]
}

is_openbsd() {
  [ "$(uname)" == "OpenBSD" ]
}

is_linux() {
  [ "$(uname)" == "Linux" ]
}

is_jetson() {
  is_linux && [ -f /etc/nv_tegra_release ]
}

is_cygwin() {
  command -v WMIC &>/dev/null
}

is_linux_iostat() {
  # Bug in early versions of linux iostat -V return error code
  iostat -c &>/dev/null
}

# is second float bigger or equal?
fcomp() {
  awk -v n1="$1" -v n2="$2" 'BEGIN {if (n1<=n2) exit 0; exit 1}'
}

load_status() {
  local percentage=$1
  local prefix=$2
  medium_thresh=$(get_tmux_option "@${prefix}_medium_thresh" "30")
  high_thresh=$(get_tmux_option "@${prefix}_high_thresh" "80")
  if fcomp "$high_thresh" "$percentage"; then
    echo "high"
  elif fcomp "$medium_thresh" "$percentage" && fcomp "$percentage" "$high_thresh"; then
    echo "medium"
  else
    echo "low"
  fi
}

temp_status() {
  local temp
  temp=$1
  cpu_temp_medium_thresh=$(get_tmux_option "@cpu_temp_medium_thresh" "80")
  cpu_temp_high_thresh=$(get_tmux_option "@cpu_temp_high_thresh" "90")
  if fcomp "$cpu_temp_high_thresh" "$temp"; then
    echo "high"
  elif fcomp "$cpu_temp_medium_thresh" "$temp" && fcomp "$temp" "$cpu_temp_high_thresh"; then
    echo "medium"
  else
    echo "low"
  fi
}

cpus_number() {
  if is_linux; then
    if command_exists "nproc"; then
      nproc
    else
      echo "$(($(sed -n 's/^processor.*:\s*\([0-9]\+\)/\1/p' /proc/cpuinfo | tail -n 1) + 1))"
    fi
  else
    sysctl -n hw.ncpu
  fi
}

command_exists() {
  local command
  command="$1"
  command -v "$command" &>/dev/null
}

# Fetches from a `macmon serve` daemon (localhost:9090, default port) rather
# than spawning `macmon pipe`, which costs ~0.8s of real CPU time per call
# just to set up/tear down its IOReport subscription - the daemon amortizes
# that cost once. Set up with: macmon serve --install
macmon_json() {
  command_exists "curl" && cached_eval curl -s "http://127.0.0.1:9090/json"
}

# Emits one Jetson stat, preferring tegrastats (ships with every L4T image)
# since it's ~8x cheaper per call than going through jetson_stats: a one-shot
# jtop connection costs ~0.5s CPU / ~2s wall (python startup + IPC handshake
# with the jtop service) vs tegrastats' ~0.05s CPU / ~0.3s wall - noticeable
# on an embedded board when it repeats every status-interval. jtop is only
# used as a fallback for boards without tegrastats on PATH. Neither needs
# sudo.
# field: cpu_pct | gpu_pct | ram_pct | swap_pct | cpu_temp | gpu_temp
jetson_stat() {
  local field="$1"
  local helpers_dir
  helpers_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if command_exists "tegrastats"; then
    local line
    line="$(cached_eval "$helpers_dir/tegrastats_line.sh")"
    [ -n "$line" ] || return
    jetson_stat_from_tegrastats "$field" "$line"
    return
  fi
  command_exists "jtop" || return
  local json
  json="$(cached_eval "$helpers_dir/jtop_stats.py")"
  [ -n "$json" ] || return
  echo "$json" | grep -Eo "\"$field\":[0-9.-]+" | grep -Eo '[0-9.-]+$'
}

jetson_stat_from_tegrastats() {
  local field="$1"
  local line="$2"
  case "$field" in
  cpu_pct)
    echo "$line" | grep -Eo 'CPU \[[^]]+\]' | grep -Eo '[0-9]+%@' | grep -Eo '[0-9]+' |
      awk '{s+=$1; n++} END {if (n>0) printf "%.2f", s/n; else print 0}'
    ;;
  gpu_pct)
    # sed capture, not grep -Eo twice: "GR3D_FREQ" itself contains a digit,
    # so re-grepping [0-9]+ out of the whole match would also grab that "3".
    echo "$line" | sed -En 's/.*GR3D_FREQ ([0-9]+)%.*/\1/p'
    ;;
  ram_pct)
    echo "$line" | grep -Eo 'RAM [0-9]+/[0-9]+MB' | grep -Eo '[0-9]+/[0-9]+' |
      awk -F/ '{if ($2>0) printf "%.2f", 100*$1/$2; else print 0}'
    ;;
  swap_pct)
    echo "$line" | grep -Eo 'SWAP [0-9]+/[0-9]+MB' | grep -Eo '[0-9]+/[0-9]+' |
      awk -F/ '{if ($2>0) printf "%.2f", 100*$1/$2; else print 0}'
    ;;
  cpu_temp)
    echo "$line" | grep -Eo 'CPU@[0-9.]+C' | grep -Eo '[0-9.]+'
    ;;
  gpu_temp)
    echo "$line" | grep -Eo 'GPU@[0-9.]+C' | grep -Eo '[0-9.]+'
    ;;
  esac
}

get_tmp_dir() {
  local tmpdir
  tmpdir="${TMPDIR:-${TMP:-${TEMP:-/tmp}}}"
  [ -d "$tmpdir" ] || local tmpdir=~/tmp
  echo "$tmpdir/tmux-$EUID-cpu"
}

get_time() {
  date +%s.%N
}

get_cache_val() {
  local key
  local timeout
  local cache
  key="$1"
  # seconds after which cache is invalidated
  timeout="${2:-2}"
  cache="$(get_tmp_dir)/$key"
  if [ -f "$cache" ]; then
    awk -v cache="$(head -n1 "$cache")" -v timeout="$timeout" -v now="$(get_time)" \
      'BEGIN {if (now - timeout < cache) exit 0; exit 1}' &&
      tail -n+2 "$cache"
  fi
}

put_cache_val() {
  local key
  local val
  local tmpdir
  key="$1"
  val="${*:2}"
  tmpdir="$(get_tmp_dir)"
  [ ! -d "$tmpdir" ] && mkdir -p "$tmpdir" && chmod 0700 "$tmpdir"
  (
    get_time
    echo -n "$val"
  ) >"$tmpdir/$key"
  echo -n "$val"
}

cached_eval() {
  local command
  local key
  local val
  command="$1"
  key="$(basename "$command")"
  val="$(get_cache_val "$key")"
  if [ -n "$val" ]; then
    echo -n "$val"
  elif command_exists "flock"; then
    cached_eval_locked "$key" "$command" "${@:2}"
  else
    put_cache_val "$key" "$($command "${@:2}")"
  fi
}

# tmux spawns each status-bar script as its own process, so several can miss
# a stale cache at the same instant and all re-run the same command in
# parallel - wasteful when the command is expensive. flock serializes the
# miss: whichever process gets the lock first refreshes the cache; the rest
# wait briefly, then read that fresh cache instead of also re-running it.
# Only used when flock is available (Linux; not preinstalled on macOS) -
# without it, cached_eval falls back to the original racy-but-harmless
# behavior.
cached_eval_locked() {
  local key="$1"
  local command="$2"
  local tmpdir lockfile val
  tmpdir="$(get_tmp_dir)"
  [ -d "$tmpdir" ] || mkdir -p "$tmpdir" && chmod 0700 "$tmpdir"
  lockfile="$tmpdir/.lock-$key"
  (
    # Wait longer than the slowest known wrapped command (tegrastats can
    # take over 1.5s to produce its first sample on weaker boards) so
    # waiters don't give up right as the lock holder is about to finish.
    flock -w 8 200 || exit 0
    val="$(get_cache_val "$key")"
    [ -n "$val" ] || put_cache_val "$key" "$("$command" "${@:3}")" >/dev/null
  ) 200>"$lockfile"
  get_cache_val "$key"
}

# Turns a monotonically increasing counter (e.g. cumulative disk bytes read)
# into a per-second rate, by diffing against the previous call's value and
# timestamp. Unlike cached_eval's TTL cache, this state persists indefinitely
# between calls rather than expiring - it's the last observed sample, not a
# cache of a repeatable command.
rate_from_counter() {
  local key="$1"
  local current="$2"
  local statefile now prev
  statefile="$(get_tmp_dir)/rate_$key"
  now="$(get_time)"
  prev="$([ -f "$statefile" ] && cat "$statefile")"
  [ -d "$(get_tmp_dir)" ] || mkdir -p "$(get_tmp_dir)"
  echo "$now $current" >"$statefile"
  awk -v prev="$prev" -v now="$now" -v current="$current" '
    BEGIN {
      if (split(prev, p, " ") == 2 && (now - p[1]) > 0 && current >= p[2]) {
        printf "%.4f", (current - p[2]) / (now - p[1])
      } else {
        print "0"
      }
    }'
}
