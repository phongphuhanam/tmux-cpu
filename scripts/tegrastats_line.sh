#!/usr/bin/env bash
# One tegrastats sample line. --interval 1 gets the first sample out as fast
# as this board can produce it - on a fast SoC (Xavier) that's tens of
# milliseconds, but on a weaker one (Nano) tegrastats' own startup cost alone
# can take over a second, sometimes past 1.5s. `timeout` needs enough margin
# above that or it kills tegrastats before any line reaches `head`, silently
# producing empty output.
timeout 5 tegrastats --interval 1 | head -n1
