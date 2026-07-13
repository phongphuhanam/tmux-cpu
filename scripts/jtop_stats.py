#!/usr/bin/env python3
# Flattens jetson_stats' jtop.stats into the small JSON blob jetson_stat()
# in helpers.sh greps from - RAM/SWAP come back as used/total fractions from
# jtop so they're rescaled to percentages here; CPU per-core and GPU load
# are already percentages.
import json

from jtop import jtop

with jtop() as jetson:
    if not jetson.ok():
        raise SystemExit(1)
    s = jetson.stats
    cpu_loads = [v for k, v in s.items() if k.startswith("CPU") and isinstance(v, (int, float))]
    out = {
        "cpu_pct": sum(cpu_loads) / len(cpu_loads) if cpu_loads else 0,
        "gpu_pct": s.get("GPU", 0),
        "ram_pct": s.get("RAM", 0) * 100,
        "swap_pct": s.get("SWAP", 0) * 100,
        "cpu_temp": s.get("Temp CPU"),
        "gpu_temp": s.get("Temp GPU"),
    }
    # Compact, no spaces - jetson_stat()'s grep patterns expect "key":value
    # like macmon's Rust-generated JSON, not json.dumps' default "key": value.
    print(json.dumps(out, separators=(",", ":")))
