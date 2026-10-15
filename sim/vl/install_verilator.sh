#!/usr/bin/env bash
# Build and install one Verilator release from source, without root.
#
# Usage: sim/vl/install_verilator.sh <tag> <prefix> [src dir]
#   <tag>      release tag, e.g. v5.052 (`git tag -l 'v5.*'` in the clone lists them)
#   <prefix>   install folder, e.g. $HOME/opt/verilator/v5.052; put <prefix>/bin in PATH afterwards
#   [src dir]  the source clone (default: <prefix>/../src/verilator; reused when it exists)
#
# Does nothing when <prefix> already holds <tag>. The clone is blobless (git 2.27 or newer).
# Needs git, autoconf, flex, bison, help2man, g++, make, perl, python3. JOBS sets the compile jobs.
set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "usage: $0 <tag> <prefix> [src dir]" >&2
    exit 1
fi
TAG=$1
PREFIX=$(realpath -m "$2")
SRC=${3:-$(dirname "$PREFIX")/src/verilator}

if [ "$("$PREFIX/bin/verilator" --version 2>/dev/null | awk '{print "v"$2}')" = "$TAG" ]; then
    echo "$PREFIX already holds Verilator $TAG"
    exit 0
fi

for t in git autoconf flex bison help2man g++ make perl python3; do
    command -v "$t" > /dev/null || { echo "missing tool: $t" >&2; exit 1; }
done

if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone --filter=blob:none https://github.com/verilator/verilator.git "$SRC"
fi
cd "$SRC"
git rev-parse -q --verify "refs/tags/$TAG^{commit}" > /dev/null || git fetch --tags origin
git checkout -q "$TAG"
[ configure -nt configure.ac ] || autoconf
./configure --prefix="$PREFIX"
make -j "${JOBS:-$(nproc)}"
make install
"$PREFIX/bin/verilator" --version
