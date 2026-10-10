#!/usr/bin/env bash
# Rebuild the pinned open-source EDA toolchain from source.
#
# Why from source: release tarballs (OSS CAD Suite) are GitHub release assets,
# which the cloud session proxy blocks; anonymous `git clone` of public repos
# works. Ubuntu 24.04 apt versions are too old (Verilator 5.020, Yosys 0.33).
#
# Usage: sudo scripts/install_toolchain.sh [PREFIX]   (default /opt/eda)
# Then:  export PATH=/opt/eda/bin:$PATH
# Takes ~30-40 min on 4 cores. Logs land in $BUILD/<tool>.log.
set -euo pipefail

PREFIX=${1:-/opt/eda}
BUILD=${BUILD:-/var/tmp/eda-build}
JOBS=${JOBS:-$(nproc)}

# Pinned versions -- keep in sync with conventions.md section 1.
VERILATOR_TAG=v5.050
IVERILOG_TAG=v13_0
YOSYS_TAG=v0.69
SBY_TAG=v0.69
YICES_TAG=yices-2.7.0
Z3_VERSION=5.1.0.0

mkdir -p "$BUILD" "$PREFIX"
export PATH="$PREFIX/bin:$PATH"

deps() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    build-essential autoconf automake flex bison help2man perl python3 \
    python3-pip python3-click cmake libfl-dev zlib1g-dev ccache gperf libgmp-dev \
    libreadline-dev tcl-dev libffi-dev pkg-config graphviz clang lld git
}

fetch() {  # fetch <url> <tag> <dir>
  rm -rf "$BUILD/$3"
  git clone -q --depth 1 --branch "$2" "$1" "$BUILD/$3"
}

build_verilator() {
  fetch https://github.com/verilator/verilator "$VERILATOR_TAG" verilator
  cd "$BUILD/verilator" && autoconf && ./configure --prefix="$PREFIX" \
    && make -j"$JOBS" && make install
}

build_iverilog() {
  fetch https://github.com/steveicarus/iverilog "$IVERILOG_TAG" iverilog
  cd "$BUILD/iverilog" && sh autoconf.sh && ./configure --prefix="$PREFIX" \
    && make -j"$JOBS" && make install
}

build_yosys() {
  fetch https://github.com/YosysHQ/yosys "$YOSYS_TAG" yosys
  # Yosys moved to CMake (>= 3.28; Ubuntu 24.04 ships 3.28).
  cd "$BUILD/yosys" && git submodule update --init --depth 1 \
    && cmake -B build . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    && cmake --build build -j"$JOBS" && cmake --install build
}

build_sby() {
  fetch https://github.com/YosysHQ/sby "$SBY_TAG" sby
  cd "$BUILD/sby" && make install PREFIX="$PREFIX"
}

build_yices() {
  fetch https://github.com/SRI-CSL/yices2 "$YICES_TAG" yices2
  cd "$BUILD/yices2" && autoconf && ./configure --prefix="$PREFIX" \
    && make -j"$JOBS" && make install
}

install_z3() {
  # The PyPI wheel ships the z3 CLI binary; no 20-minute source build needed.
  pip3 install -q --break-system-packages "z3-solver==$Z3_VERSION"
  ln -sf "$(command -v z3)" "$PREFIX/bin/z3"
}

deps
for t in verilator iverilog yices; do
  ( "build_$t" >"$BUILD/$t.log" 2>&1 && echo "OK   $t" || echo "FAIL $t (see $BUILD/$t.log)" ) &
done
wait
# sby installs into the yosys prefix, so yosys first.
( build_yosys >"$BUILD/yosys.log" 2>&1 && echo "OK   yosys" || echo "FAIL yosys (see $BUILD/yosys.log)" )
( build_sby   >"$BUILD/sby.log"   2>&1 && echo "OK   sby"   || echo "FAIL sby (see $BUILD/sby.log)" )
( install_z3  >"$BUILD/z3.log"    2>&1 && echo "OK   z3"    || echo "FAIL z3 (see $BUILD/z3.log)" )

echo "--- installed versions ---"
# `cmd | head -1` would SIGPIPE under pipefail (exit 141), so use sed -n 1p.
set +o pipefail
verilator --version; iverilog -V 2>&1 | sed -n 1p; yosys -V
sby --help >/dev/null && echo "sby OK"; yices --version | sed -n 1p; z3 --version
