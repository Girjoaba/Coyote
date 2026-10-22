#!/usr/bin/env bash
# Turn a folder written by sim/vl/freeze.sh into a build folder for sim/vl/build.sh, without Vivado.
#
# Usage: sim/vl/unfreeze.sh <frozen dir> <work dir> [<src root>]
#   <frozen dir>  output of sim/vl/freeze.sh
#   <work dir>    the build folder to create (what COYOTE_SIM_DIR and build.sh take)
#   <src root>    the checkout with the design sources (default: this Coyote checkout)
#
# Then: sim/vl/build.sh <work dir> <out dir>
set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "usage: $0 <frozen dir> <work dir> [<src root>]" >&2
    exit 1
fi
FROZEN=$(realpath "$1")
mkdir -p "$2"
WORK=$(realpath "$2")
VL=$(realpath "$(dirname "$0")")
SRC=$(realpath "${3:-$VL/../..}")

[ -f "$FROZEN/files.f" ] || { echo "$FROZEN holds no files.f" >&2; exit 1; }
cp -r "$FROZEN/build/." "$WORK/"
SUBST="s#@BUILD_DIR@#$WORK#g; s#@SRC_DIR@#$SRC#g"
sed "$SUBST" "$FROZEN/files.f" > "$WORK/files.f"
sed "$SUBST" "$FROZEN/incs.f" > "$WORK/incs.f"
sed -i "$SUBST" "$WORK/sim/lynx_pkg.sv"
if [ -f "$FROZEN/coyote_test_init.py" ]; then
    mkdir -p "$WORK/coyote_test"
    sed "$SUBST" "$FROZEN/coyote_test_init.py" > "$WORK/coyote_test/__init__.py"
fi
while read -r p; do
    [ -f "$p" ] || { echo "missing source $p (wrong <src root>?)" >&2; exit 1; }
done < "$WORK/files.f"
echo "$WORK: $(wc -l < "$WORK/files.f") sources, build with: $VL/build.sh $WORK <out dir>"
