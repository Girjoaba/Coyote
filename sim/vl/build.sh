#!/usr/bin/env bash
# Build the Coyote simulation testbench (sim/hw/tb_user.sv) with Verilator.
#
# Usage: sim/vl/build.sh <hw build dir> <out dir>
#   <hw build dir>  the hardware build folder where `make sim` ran (what COYOTE_SIM_DIR points to)
#   <out dir>       output folder; the binary is <out dir>/coyote_vl
#
# Run the host program against the binary with:
#   COYOTE_SIM_BIN=<out dir>/coyote_vl COYOTE_SIM_DIR=<hw build dir> ./test ...
#
# Needs Verilator 5 in PATH. JOBS (default 16) sets the parallel compile jobs.
# The source list and the include folders come from the xsim project that `make sim` wrote,
# so Verilator compiles the same files as xsim.
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "usage: $0 <hw build dir> <out dir>" >&2
    exit 1
fi

HW=$(realpath "$1")
mkdir -p "$2"
OUT=$(realpath "$2")
DPI=$(realpath "$(dirname "$0")/../hw/dpi")

# The xsim project folder written by `make sim`. tb_user_vlog.prj lists the sources in compile order.
XSIM=$(ls -d "$HW"/sim/*.sim/sim_1/behav/xsim 2>/dev/null | head -1)
PRJ="$XSIM/tb_user_vlog.prj"
if [ ! -f "$PRJ" ]; then
    echo "$HW/sim/*.sim/sim_1/behav/xsim/tb_user_vlog.prj not found: run 'make sim' in $HW first" >&2
    exit 1
fi

# 1. Verilator does not parse `1step`. At the time precision of 1 ps, 1ps is the same value.
sed 's/1step/1ps/' "$HW/sim/lynx_pkg.sv" > "$OUT/lynx_pkg.sv"

# 2. The project sources in xsim order, without glbl.v (Xilinx primitives, xsim only).
#    lynx_pkg.sv is taken from the copy of step 1.
grep -oE '"[^"]+\.s?v"' "$PRJ" | tr -d '"' | grep -v 'glbl\.v$' \
    | (cd "$XSIM" && xargs realpath) \
    | sed "s#.*/lynx_pkg\.sv\$#$OUT/lynx_pkg.sv#" > "$OUT/files.f"

# 3. The IP library sources (<ip>/hdl/*.v), which xsim loads precompiled, one copy per file name.
#    They have `timescale 1ps/1ps and must stay after the 1ns/1ps project sources: Verilator gives
#    the testbench classes the time unit of the first file.
shopt -s nullglob
IP_SRCS=("$HW"/sim/*.gen/sources_1/ip/*/hdl/*.v)
shopt -u nullglob
if [ ${#IP_SRCS[@]} -gt 0 ]; then
    printf '%s\n' "${IP_SRCS[@]}" | awk -F/ '!seen[$NF]++' >> "$OUT/files.f"
fi

# 4. The include folders of the xsim project.
grep -oE -- '--include "[^"]+"' "$PRJ" | cut -d'"' -f2 | sort -u \
    | (cd "$XSIM" && xargs realpath) | sed 's/^/-I/' > "$OUT/incs.f"

# 5. Build. -O1 runs faster than the Verilator default -Os at the same compile time.
#    file_io.c (the pipe reader, DPI-C) has extern "C" guards and compiles as C++.
if ! verilator --binary --timing -j "${JOBS:-16}" -CFLAGS -O1 \
        -Wno-fatal -Wno-lint -Wno-style \
        -DEN_RANDOMIZATION -DEN_INTERACTIVE \
        -f "$OUT/incs.f" -f "$OUT/files.f" "$DPI/file_io.c" \
        --top-module tb_user --Mdir "$OUT/obj" -o coyote_vl > "$OUT/build.log" 2>&1; then
    grep '^%Error' "$OUT/build.log" | head -20 >&2
    echo "verilator failed, see $OUT/build.log" >&2
    exit 1
fi

ln -sfn obj/coyote_vl "$OUT/coyote_vl"
tail -1 "$OUT/build.log"
echo "$OUT/coyote_vl"
