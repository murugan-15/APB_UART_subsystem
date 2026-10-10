#!/usr/bin/env bash
# M0 toolchain capability probes.
#
# Runs every (probe, check) pair, writes one line per check to
# build/probe/results.txt, and compares against tb/probes/expected.txt.
#   PASS    : the tool supports the feature correctly (incl. dual/anti-vacuity checks)
#   FAIL    : it does not (a known gap if expected.txt says FAIL)
#   UNAVAIL : the tool / library is not installed
# Exit 0 iff results match the baseline exactly; any change, better or
# worse, exits 1 so the baseline is updated on purpose (make probe-accept).
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROBES=$ROOT/tb/probes
OUT=${OUT:-$ROOT/build/probe}
EXPECTED=$PROBES/expected.txt
RESULTS=$OUT/results.txt
SIM_TIMEOUT=120
FORMAL_TIMEOUT=600

rm -rf "$OUT"
mkdir -p "$OUT"
: >"$RESULTS"

have() { command -v "$1" >/dev/null 2>&1; }

record() { printf '%-26s %-22s %s\n' "$1" "$2" "$3" | tee -a "$RESULTS"; }

# check <probe> <check-name> <required-binary> <function> [args...]
# Runs <function> in a fresh copy of the probe directory; its exit status is
# the verdict. All output goes to $OUT/<probe>/<check>/log.txt.
check() {
  local probe=$1 name=$2 bin=$3
  shift 3
  if ! have "$bin"; then
    record "$probe" "$name" UNAVAIL
    return
  fi
  local dir=$OUT/$probe/$name
  mkdir -p "$dir"
  cp -r "$PROBES/$probe/." "$dir/"
  if (cd "$dir" && "$@") >"$dir/log.txt" 2>&1; then
    record "$probe" "$name" PASS
  else
    record "$probe" "$name" FAIL
  fi
}

# ---------------------------------------------------------------- helpers ---
# All helpers run inside the check directory.

# Sim verdict: clean exit AND PROBE_PASS printed AND no PROBE_FAIL.
sim_verdict() {
  local rc=$1
  cat sim.log
  [ "$rc" -eq 0 ] && grep -q PROBE_PASS sim.log && ! grep -q PROBE_FAIL sim.log
}

vl_build() {  # vl_build <top> <files/flags...>
  local top=$1
  shift
  verilator --binary --timing --assert -j 0 -Mdir obj --top-module "$top" "$@"
}

vl_sim() {  # vl_sim <top> <files/flags...>
  local top=$1
  vl_build "$@" || return 1
  timeout "$SIM_TIMEOUT" "./obj/V$top" >sim.log 2>&1
  sim_verdict $?
}

iv_build() {
  local top=$1
  shift
  iverilog -g2012 -s "$top" -o sim.vvp "$@"
}

iv_sim() {
  iv_build "$@" || return 1
  timeout "$SIM_TIMEOUT" vvp -n sim.vvp >sim.log 2>&1
  sim_verdict $?
}

# The run must exit nonzero (not a timeout) and must not reach the end.
must_fail_run() {
  local rc=$1
  cat sim.log
  [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ] && ! grep -q "reached end" sim.log
}

vl_sim_must_fail() {
  local top=$1
  vl_build "$@" || return 1
  timeout "$SIM_TIMEOUT" "./obj/V$top" >sim.log 2>&1
  must_fail_run $?
}

iv_sim_must_fail() {
  iv_build "$@" || return 1
  timeout "$SIM_TIMEOUT" vvp -n sim.vvp >sim.log 2>&1
  must_fail_run $?
}

ys_synth() {  # ys_synth <top> <files...>
  local top=$1
  shift
  yosys -q -p "read_verilog -sv $*; synth -top $top; check -assert"
}

# sby_status <sbyfile> <task>: prints the task's final status word
# (PASS / FAIL / ERROR / UNKNOWN / TIMEOUT).
sby_status() {
  local f=$1 t=$2 dir
  dir="$(basename "$f" .sby)_$t"
  timeout "$FORMAL_TIMEOUT" sby -f "$f" "$t" >"sby_$t.log" 2>&1
  if [ -f "$dir/status" ]; then
    awk '{print $1; exit}' "$dir/status"
  else
    echo ERROR
  fi
}

# sby_expect <sbyfile> <task> <expected-status> [<task> <expected-status>]...
sby_expect() {
  local f=$1 ok=0 t want got
  shift
  while [ $# -gt 0 ]; do
    t=$1 want=$2
    shift 2
    got=$(sby_status "$f" "$t")
    echo "task $t: got $got, want $want"
    [ "$got" = "$want" ] || ok=1
  done
  return $ok
}

# --------------------------------------------------------------- p08 dual ---
# Legal top must elaborate; illegal top must be rejected WITH our message.
elab_dual() {  # elab_dual <elab-command...>  (top name appended)
  "$@" p08_top_good >good.log 2>&1 || { cat good.log; return 1; }
  if "$@" p08_top_bad >bad.log 2>&1; then
    cat bad.log
    return 1
  fi
  cat bad.log
  grep -q "W must be >= 2" bad.log
}
vl_elab()        { verilator --lint-only dut.sv --top-module "$1"; }
vl_elab_nofatal(){ verilator --lint-only -Wno-fatal dut.sv --top-module "$1"; }
iv_elab()        { iverilog -g2012 -o /dev/null -s "$1" dut.sv; }
iv_elab_fmt()    { iverilog -g2012 -DFMT_ARGS -o /dev/null -s "$1" dut.sv; }
ys_elab()        { yosys -q -p "read_verilog -sv dut.sv; hierarchy -check -top $1"; }

# --------------------------------------------------------------- p11 trace --
sby_p11() {
  sby_expect p11.sby good PASS bad FAIL || return 1
  # A FAIL is only useful with a counterexample to look at.
  ls p11_bad/engine_0/trace*.vcd
}

# --------------------------------------------------------------- p15 UVM ----
uvm_present() { [ -n "${UVM_HOME:-}" ] && [ -f "$UVM_HOME/src/uvm_pkg.sv" ]; }
vl_uvm() {
  vl_sim p15_tb +incdir+"$UVM_HOME/src" "$UVM_HOME/src/uvm_pkg.sv" tb.sv
}

# ----------------------------------------------------------------- probes ---
check p01_sv_basics          verilator      verilator vl_sim p01_tb dut.sv tb.sv
check p01_sv_basics          iverilog       iverilog  iv_sim p01_tb dut.sv tb.sv
check p01_sv_basics          yosys-synth    yosys     ys_synth p01_dut dut.sv

check p02_interfaces         verilator      verilator vl_sim p02_tb dut.sv tb.sv
check p02_interfaces         iverilog       iverilog  iv_sim p02_tb dut.sv tb.sv
check p02_interfaces         yosys-synth    yosys     ys_synth p02_dut dut.sv

check p03_packages_generate  verilator      verilator vl_sim p03_tb dut.sv tb.sv
check p03_packages_generate  iverilog       iverilog  iv_sim p03_tb dut.sv tb.sv
check p03_packages_generate  yosys-synth    yosys     ys_synth p03_dut dut.sv
check p03_packages_generate  yosys-return   yosys     ys_synth p03_dut -DUSE_RETURN dut.sv
check p03_packages_generate  yosys-header-import yosys ys_synth p03_dut -DHEADER_IMPORT dut.sv
check p03_packages_generate  yosys-body-import yosys  ys_synth p03_dut -DBODY_IMPORT dut.sv

check p04_nba_ordering       verilator      verilator vl_sim p04_tb dut.sv tb.sv
check p04_nba_ordering       iverilog       iverilog  iv_sim p04_tb dut.sv tb.sv

check p05_classes            verilator      verilator vl_sim p05_tb tb.sv
check p05_classes            iverilog       iverilog  iv_sim p05_tb tb.sv

check p06_randomize          verilator      verilator vl_sim p06_tb tb.sv
check p06_randomize          iverilog       iverilog  iv_sim p06_tb tb.sv

check p07_immediate_assert   verilator      verilator vl_sim p07_tb_actions tb_actions.sv
check p07_immediate_assert   iverilog       iverilog  iv_sim p07_tb_actions tb_actions.sv
check p07_immediate_assert   verilator-exit verilator vl_sim_must_fail p07_tb_exit tb_exit.sv
check p07_immediate_assert   iverilog-exit  iverilog  iv_sim_must_fail p07_tb_exit tb_exit.sv

check p08_elab_error         verilator      verilator elab_dual vl_elab
check p08_elab_error         verilator-wnofatal verilator elab_dual vl_elab_nofatal
check p08_elab_error         iverilog       iverilog  elab_dual iv_elab
check p08_elab_error         iverilog-fmtargs iverilog elab_dual iv_elab_fmt
check p08_elab_error         yosys          yosys     elab_dual ys_elab

check p09_concurrent_sva_sim verilator      verilator vl_sim p09_tb tb.sv
check p09_concurrent_sva_sim iverilog       iverilog  iv_sim p09_tb tb.sv

check p10_concurrent_sva_formal sby         sby       sby_expect p10.sby good PASS bad FAIL

check p11_formal_past_guard  sby-dual-trace sby       sby_p11
check p11_formal_past_guard  sby-noguard    sby       sby_expect p11.sby noguard FAIL

check p12_bind               verilator      verilator vl_sim p12_tb dut.sv bind.sv tb.sv
check p12_bind               iverilog       iverilog  iv_sim p12_tb dut.sv bind.sv tb.sv
check p12_bind               sby            sby       sby_expect p12.sby good PASS bad FAIL

check p13_assume_macro       verilator      verilator vl_sim p13_tb_legal dut.sv tb.sv
check p13_assume_macro       verilator-fire verilator vl_sim_must_fail p13_tb_illegal dut.sv tb.sv
check p13_assume_macro       sby            sby       sby_expect p13.sby with_assume PASS no_assume FAIL

check p14_bmc_vs_prove       sby            sby       sby_expect p14.sby bmc24 PASS pdr FAIL good PASS

if uvm_present; then
  check p15_uvm              verilator      verilator vl_uvm
else
  record p15_uvm verilator UNAVAIL
fi

# ---------------------------------------------------------------- summary ---
echo
printf 'PASS %d  FAIL %d  UNAVAIL %d\n' \
  "$(grep -c ' PASS$' "$RESULTS")" "$(grep -c ' FAIL$' "$RESULTS")" \
  "$(grep -c ' UNAVAIL$' "$RESULTS")"

if [ ! -f "$EXPECTED" ]; then
  echo "No baseline at $EXPECTED (run: make probe-accept)"
  exit 1
fi
if diff -u "$EXPECTED" "$RESULTS" >"$OUT/diff.txt"; then
  echo "Probe results match baseline."
  exit 0
fi
echo "Probe results DIFFER from baseline (see $OUT/diff.txt):"
cat "$OUT/diff.txt"
exit 1
