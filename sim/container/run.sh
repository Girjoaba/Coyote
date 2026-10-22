#!/usr/bin/env bash
# Run the frozen example under Verilator: the host program, then the Python tests of sim/unit_test/examples.
# Usage: run.sh [host program arguments]   (default: -X 1024 -r 1 -s 0)
set -euo pipefail
WORK=${WORK:-/work}
COYOTE=${COYOTE:-/opt/coyote}
export PATH=${PREFIX:-/opt/verilator}/bin:$PATH

if [ $# -eq 0 ]; then
    set -- -X 1024 -r 1 -s 0
fi
cd "$WORK/sw"
COYOTE_SIM_BIN=$WORK/vl_cpp/coyote_vl COYOTE_SIM_DIR=$WORK ./test "$@"
tail -1 "$WORK/sim/coyote_vl.log"

COYOTE_SIM_VERILATOR=1 PYTHONPATH=$WORK:$COYOTE/sim \
    python3 -m unittest discover -s "$COYOTE/sim/unit_test/examples"
