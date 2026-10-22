#!/usr/bin/env bash
# Store what a Verilator build of the testbench needs, so that a machine without Vivado can build it.
#
# Usage: sim/vl/freeze.sh <hw build dir> <vl out dir> <frozen dir> [<src root>]
#   <hw build dir>  the hardware build folder where `make sim` ran
#   <vl out dir>    the output folder of a sim/vl/build.sh run on it (files.f, incs.f)
#   <frozen dir>    where the lists and the generated files go (created)
#   <src root>      the checkout that holds the design sources (default: this Coyote checkout)
#
# The frozen folder holds files.f and incs.f with @SRC_DIR@ and @BUILD_DIR@ in place of the two
# roots, the files Vivado generated under <hw build dir> (lynx_pkg.sv, the user logic wrapper,
# vfpga_top.svh, IP simulation sources), coyote_test_init.py for the Python framework, and
# FROZEN with the provenance. sim/vl/unfreeze.sh turns it back into a build folder.
set -euo pipefail

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "usage: $0 <hw build dir> <vl out dir> <frozen dir> [<src root>]" >&2
    exit 1
fi
HW=$(realpath "$1")
OUT=$(realpath "$2")
mkdir -p "$3"
FROZEN=$(realpath "$3")
VL=$(realpath "$(dirname "$0")")
SRC=$(realpath "${4:-$VL/../..}")

for f in files.f incs.f; do
    [ -f "$OUT/$f" ] || { echo "$OUT/$f missing: run sim/vl/build.sh $HW $OUT first" >&2; exit 1; }
done

SUBST="s#$HW#@BUILD_DIR@#g; s#$SRC#@SRC_DIR@#g"

# A path under the build folder (a file, or an include folder) is copied and rewritten; one under the source root is rewritten.
place() {
    local p=$1
    case "$p" in
        "$OUT"/lynx_pkg.sv)
            mkdir -p "$FROZEN/build/sim"
            sed "$SUBST" "$p" > "$FROZEN/build/sim/lynx_pkg.sv"
            echo "@BUILD_DIR@/sim/lynx_pkg.sv" ;;
        "$HW"/*)
            mkdir -p "$FROZEN/build/$(dirname "${p#$HW/}")"
            cp -r "$p" "$FROZEN/build/${p#$HW/}"
            echo "@BUILD_DIR@/${p#$HW/}" ;;
        "$SRC"/*)
            echo "@SRC_DIR@/${p#$SRC/}" ;;
        *)
            echo "$p is neither under $HW nor under $SRC" >&2
            exit 1 ;;
    esac
}

rm -rf "$FROZEN/build"
while read -r p; do place "$p"; done < "$OUT/files.f" > "$FROZEN/files.f"
while read -r p; do echo "-I$(place "${p#-I}")"; done < "$OUT/incs.f" > "$FROZEN/incs.f"
# vfpga_top.svh is included relative to its includer (the user logic wrapper), so no list names it.
[ -f "$HW/sim/vfpga_top.svh" ] && cp "$HW/sim/vfpga_top.svh" "$FROZEN/build/sim/"
if [ -f "$HW/coyote_test/__init__.py" ]; then
    sed "$SUBST" "$HW/coyote_test/__init__.py" > "$FROZEN/coyote_test_init.py"
fi
{
    echo "date: $(date -Is)"
    echo "hw_build: $HW"
    echo "src_root: $SRC"
    echo "src_commit: $(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "vivado: $(grep -m1 -o 'Vivado v[0-9.]*' "$HW"/vivado.log 2>/dev/null || echo unknown)"
} > "$FROZEN/FROZEN"
echo "$FROZEN: $(wc -l < "$FROZEN/files.f") sources, $(find "$FROZEN/build" -type f | wc -l) generated files"
