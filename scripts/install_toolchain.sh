#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 murugan-15
#
# Rebuild the pinned open-source EDA toolchain from source (D-004, D-013).
#
# Why from source: release tarballs (OSS CAD Suite) are GitHub release assets,
# which the cloud session proxy blocks; anonymous `git clone` of public repos
# works. Ubuntu 24.04 apt versions are too old (Verilator 5.020, Yosys 0.33).
#
# Usage: sudo scripts/install_toolchain.sh [PREFIX]   (default /opt/eda)
# Then:  export PATH=/opt/eda/bin:$PATH
# Takes an estimated 40-60 min on 4 cores the first time (not timed end to end). Logs land in $BUILD/<tool>.log.
# A tool already installed at its pinned version is skipped, so the script can
# be re-run after a version bump or to add the tools of D-013.
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
# D-013: mutation cover, equivalence, UVM library, style lint. Python tools are
# pinned in requirements-tools.txt; lcov, sigrok-cli and gawk come from apt.
MCY_TAG=v0.69
EQY_TAG=v0.69
UVM_TAG=uvm-2020-3.2
SVLINT_VERSION=0.9.5

mkdir -p "$BUILD" "$PREFIX"
export PATH="$PREFIX/bin:$PATH"

deps() {
  # Fresh containers ship with empty package lists.
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    build-essential autoconf automake flex bison help2man perl python3 \
    python3-pip python3-click cmake libfl-dev zlib1g-dev ccache gperf libgmp-dev \
    libreadline-dev tcl-dev libffi-dev pkg-config graphviz clang lld git \
    gawk lcov sigrok-cli liblz4-dev xxd
  command -v cargo >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cargo
}

# has <command> <version-flag> <text>: true when the installed tool reports <text>.
# The output is captured first: `cmd | grep -q` would SIGPIPE under pipefail.
has() {
  local out
  command -v "$1" >/dev/null 2>&1 || return 1
  out=$("$1" "$2" 2>&1) || true
  case $out in *"$3"*) return 0 ;; *) return 1 ;; esac
}

fetch() {  # fetch <url> <tag> <dir>
  rm -rf "${BUILD:?}/${3:?}"
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

build_mcy() {
  # Command-line tool only: `make install` would also build the Qt dashboard.
  fetch https://github.com/YosysHQ/mcy "$MCY_TAG" mcy
  cd "$BUILD/mcy" && install mcy.py "$PREFIX/bin/mcy" \
    && mkdir -p "$PREFIX/share/mcy/scripts" && cp -r scripts/. "$PREFIX/share/mcy/scripts/." \
    && echo "$MCY_TAG" >"$PREFIX/share/mcy/VERSION"
}

build_eqy() {
  fetch https://github.com/YosysHQ/eqy "$EQY_TAG" eqy
  cd "$BUILD/eqy" && make -j"$JOBS" PREFIX="$PREFIX" install \
    && mkdir -p "$PREFIX/share/eqy" && echo "$EQY_TAG" >"$PREFIX/share/eqy/VERSION"
}

install_uvm() {
  # CHIPS Alliance's UVM 2020 kit with a Verilator DPI backend (source only).
  rm -rf "$PREFIX/share/uvm-verilator"
  git clone -q --depth 1 --branch "$UVM_TAG" https://github.com/chipsalliance/uvm-verilator \
    "$PREFIX/share/uvm-verilator" && echo "$UVM_TAG" >"$PREFIX/share/uvm-verilator/VERSION"
}

install_svlint() {
  cargo install -q --locked --root "$PREFIX" svlint --version "$SVLINT_VERSION"
}

install_pytools() {
  pip3 install -q --break-system-packages -r "$ROOT/requirements-tools.txt"
}

# step <name> <function> <skip-test...>: run <function> unless <skip-test> succeeds.
# Runs in a subshell (the build functions cd); the verdict also goes to $STATUS.
step() (
  name=$1 fn=$2
  shift 2
  if "$@" >/dev/null 2>&1; then
    echo "SKIP $name (already at the pinned version)" | tee -a "$STATUS"
  elif "$fn" >"$BUILD/$name.log" 2>&1; then
    echo "OK   $name" | tee -a "$STATUS"
  else
    echo "FAIL $name (see $BUILD/$name.log)" | tee -a "$STATUS"
  fi
)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
STATUS=$BUILD/status.txt
: >"$STATUS"
IVERILOG_VER=${IVERILOG_TAG#v}
deps
# The three independent source builds run in parallel.
step verilator build_verilator has verilator --version "${VERILATOR_TAG#v}" &
step iverilog  build_iverilog  has iverilog -V "version ${IVERILOG_VER//_/.}" &
step yices     build_yices     has yices --version "${YICES_TAG#yices-}" &
wait
# sby, mcy and eqy install into the yosys prefix, so yosys first.
step yosys     build_yosys     has yosys -V "Yosys ${YOSYS_TAG#v} "
step sby       build_sby       test -x "$PREFIX/bin/sby"
step z3        install_z3      has z3 --version "${Z3_VERSION%.0}"
step mcy       build_mcy       grep -qxF "$MCY_TAG" "$PREFIX/share/mcy/VERSION"
step eqy       build_eqy       grep -qxF "$EQY_TAG" "$PREFIX/share/eqy/VERSION"
step uvm       install_uvm     grep -qxF "$UVM_TAG" "$PREFIX/share/uvm-verilator/VERSION"
step svlint    install_svlint  has svlint --version "$SVLINT_VERSION"
step pytools   install_pytools false

echo "--- installed versions ---"
# `cmd | head -1` would SIGPIPE under pipefail (exit 141), so use sed -n 1p.
set +o pipefail
verilator --version; iverilog -V 2>&1 | sed -n 1p; yosys -V
sby --help >/dev/null && echo "sby OK"; yices --version | sed -n 1p; z3 --version
echo "mcy $(cat "$PREFIX/share/mcy/VERSION" 2>/dev/null || echo missing)"
echo "eqy $(cat "$PREFIX/share/eqy/VERSION" 2>/dev/null || echo missing)"
echo "uvm-verilator $(cat "$PREFIX/share/uvm-verilator/VERSION" 2>/dev/null || echo missing)"
svlint --version; lcov --version | sed -n 1p; sigrok-cli --version | sed -n 1p
echo "peakrdl $(peakrdl --version 2>&1 | sed -n 1p)"; reuse --version | sed -n 1p
echo "fusesoc $(fusesoc --version 2>&1 | sed -n 1p)"
python3 -c "import pyslang; print('pyslang', pyslang.__version__)"
# Nonzero exit if any step failed, so a CI image build cannot succeed with a tool missing.
! grep -q '^FAIL' "$STATUS"
