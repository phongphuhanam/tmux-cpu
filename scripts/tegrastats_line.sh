#!/usr/bin/env bash
# One tegrastats sample line, for boards without jetson_stats installed.
# --interval 1 plus `head -n1` keeps this to tens of milliseconds; `timeout`
# is just a safety net in case head doesn't kill tegrastats fast enough.
timeout 1 tegrastats --interval 1 | head -n1
