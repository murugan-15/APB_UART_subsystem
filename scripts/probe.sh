#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 murugan-15
#
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
# UVM_HOME defaults to the uvm-verilator kit that install_toolchain.sh puts
# next to the pinned Verilator (D-012).
: "${UVM_HOME:=$(dirname "$(command -v verilator 2>/dev/null || echo /nonexistent/bin/verilator)")/../share/uvm-verilator}"
uvm_present() { [ -f "$UVM_HOME/src/uvm_pkg.sv" ] && [ -f "$UVM_HOME/src/dpi/uvm_dpi.cc" ]; }
# The UVM library takes about two minutes to compile, so the three p15 checks
# share one build, kept outside the per-check directories.
uvm_bin() {
  local cache=$OUT/p15_uvm/_build
  if [ ! -x "$cache/Vp15_tb" ]; then
    verilator --binary --timing --vpi -j 0 -Mdir "$cache" --top-module p15_tb uvm.vlt \
      +incdir+"$UVM_HOME/src" "$UVM_HOME/src/uvm_pkg.sv" "$UVM_HOME/src/dpi/uvm_dpi.cc" tb.sv || return 1
  fi
  echo "$cache/Vp15_tb"
}
# A UVM run is clean only if the report server counted no error and no fatal.
uvm_report_clean() { grep -Eq '^UVM_ERROR : +0$' sim.log && grep -Eq '^UVM_FATAL : +0$' sim.log; }
vl_uvm() {
  local bin
  bin=$(uvm_bin | tail -1) && [ -x "$bin" ] || return 1
  timeout "$SIM_TIMEOUT" "$bin" >sim.log 2>&1
  sim_verdict $? && uvm_report_clean
}
# Anti-vacuity, part 1: a planted uvm_error should make the run exit nonzero.
# It does not (the run still exits 0), so this check is a known FAIL.
vl_uvm_error_exit() {
  local bin
  bin=$(uvm_bin | tail -1) && [ -x "$bin" ] || return 1
  timeout "$SIM_TIMEOUT" "$bin" +UVM_ERR >sim.log 2>&1
  must_fail_run $?
}
# Anti-vacuity, part 2: the report counts do show the planted error.
vl_uvm_error_report() {
  local bin
  bin=$(uvm_bin | tail -1) && [ -x "$bin" ] || return 1
  timeout "$SIM_TIMEOUT" "$bin" +UVM_ERR >sim.log 2>&1
  cat sim.log
  ! uvm_report_clean && grep -Eq '^UVM_ERROR : +1$' sim.log
}

# ------------------------------------------------------- p16 struct ports ---
# The twin testbench expects a wrong value: it must print PROBE_FAIL.
vl_sim_twin() {
  local top=$1
  vl_build "$@" || return 1
  timeout "$SIM_TIMEOUT" "./obj/V$top" >sim.log 2>&1
  cat sim.log
  grep -q PROBE_FAIL sim.log && ! grep -q PROBE_PASS sim.log
}

# ---------------------------------------------------- p17 coverage report ---
vl_cov_html() {
  verilator --binary --timing --assert --coverage -j 0 -Mdir obj --top-module p17_tb dut.sv tb.sv || return 1
  timeout "$SIM_TIMEOUT" ./obj/Vp17_tb >sim.log 2>&1
  sim_verdict $? || return 1
  verilator_coverage --write-info cov.info coverage.dat || return 1
  genhtml -q cov.info -o html || return 1
  [ -f html/index.html ] || return 1
  # At least one line was executed, and the never-taken branch is reported with count 0.
  grep -Eq '^DA:[0-9]+,[1-9]' cov.info && grep -Eq '^DA:[0-9]+,0$' cov.info
}

# --------------------------------------------------------- p18 equivalence --
eqy_dual() {
  eqy -f gate.eqy >gate.log 2>&1 || { cat gate.log; return 1; }
  if eqy -f bad.eqy >bad.log 2>&1; then
    cat bad.log
    return 1
  fi
  tail -5 gate.log bad.log
  grep -q 'DONE (PASS' gate.log && grep -q 'DONE (FAIL' bad.log
}

# ----------------------------------------------------------- p19 mutation ---
# mcy_tags <defs>: run 40 mutations, print "COVERED n UNCOVERED m".
mcy_tags() {
  rm -rf database tasks
  mcy init >init.log 2>&1 || { cat init.log; return 1; }
  P19_DEFS=$1 mcy run -j "$(nproc)" >run.log 2>&1 || { tail -20 run.log; return 1; }
  mcy status 2>&1 | grep -E '^COVERED [0-9]+ UNCOVERED [0-9]+$'
}
mcy_dual() {
  local good weak
  good=$(mcy_tags "") || return 1
  weak=$(mcy_tags "-DWEAK") || return 1
  echo "checking testbench: $good"
  echo "blind testbench:    $weak"
  # The checking testbench covers most mutations; the blind one covers none.
  set -- $good
  [ "$2" -ge 30 ] || return 1
  set -- $weak
  [ "$2" -eq 0 ] && [ "$4" -eq 40 ]
}

# ------------------------------------------------------- p20 line monitor ---
sigrok_bytes() {  # sigrok_bytes <baud>: decoded bytes on one line
  sigrok-cli -I vcd -i tx_pin.vcd -P "uart:rx=tx:baudrate=$1:format=hex" -A uart=rx-data 2>&1 \
    | awk '{printf "%s ", $2} END {print ""}'
}
vl_line_monitor() {
  verilator --binary --timing --trace -j 0 -Mdir obj --top-module p20_tb tb.sv || return 1
  timeout "$SIM_TIMEOUT" ./obj/Vp20_tb >sim.log 2>&1
  sim_verdict $? || return 1
  python3 "$ROOT/scripts/vcd_pin.py" tx.vcd p20_tb tx tx_pin.vcd || return 1
  local right wrong
  right=$(sigrok_bytes 115200)
  wrong=$(sigrok_bytes 57600)
  echo "at 115200: $right"
  echo "at  57600: $wrong"
  [ "$right" = "41 55 A5 " ] && [ "$wrong" != "41 55 A5 " ]
}

# ------------------------------------------------- p21 register generation --
rdl_dual() {
  peakrdl c-header regs.rdl -o regs.h || return 1
  grep -q 'INT_STATUS' regs.h || return 1
  peakrdl markdown regs.rdl -o regs.md || return 1
  # Reference register block: flat APB3 ports (rule 2) and the reset of D-001.
  peakrdl regblock regs.rdl -o rb --cpuif apb3-flat --default-reset arst_n --err-if-bad-addr || return 1
  # MULTIDRIVEN is waived for this generated block only: it writes different members of one
  # struct from different always_ff blocks, which Verilator reports per whole struct.
  verilator --lint-only -Wno-MULTIDRIVEN rb/p21_regs_pkg.sv rb/p21_regs.sv --top-module p21_regs || return 1
  python3 "$ROOT/scripts/slang_check.py" rb/p21_regs_pkg.sv rb/p21_regs.sv || return 1
  # Anti-vacuity: two registers at one offset must be rejected.
  if peakrdl c-header overlap.rdl -o overlap.h >overlap.log 2>&1; then
    cat overlap.log
    return 1
  fi
  cat overlap.log
}

# --------------------------------------------------- p22 second front end ---
slang_dual() {
  python3 "$ROOT/scripts/slang_check.py" good.sv || return 1
  if python3 "$ROOT/scripts/slang_check.py" bad.sv >bad.log 2>&1; then
    cat bad.log
    return 1
  fi
  cat bad.log
  grep -q 'error' bad.log
}
# The same illegal file under Icarus: pinned, because Icarus accepts it.
iv_reject_bad() {
  if iverilog -g2012 -o /dev/null bad.sv >bad.log 2>&1; then
    cat bad.log
    return 1
  fi
}

# ------------------------------------------------------- p23 style lint -----
svlint_dual() {
  svlint -c "$ROOT/.svlint.toml" clean.sv || return 1
  if svlint -c "$ROOT/.svlint.toml" twin.sv >twin.log 2>&1; then
    cat twin.log
    return 1
  fi
  cat twin.log
  grep -q 'blocking_assignment_in_always_ff' twin.log && grep -q 'default_nettype_none' twin.log \
    && grep -q 'keyword_forbidden_always' twin.log
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
  check p15_uvm              verilator-error-exit   verilator vl_uvm_error_exit
  check p15_uvm              verilator-error-report verilator vl_uvm_error_report
else
  record p15_uvm verilator UNAVAIL
  record p15_uvm verilator-error-exit UNAVAIL
  record p15_uvm verilator-error-report UNAVAIL
fi

check p16_struct_port        verilator      verilator vl_sim p16_tb dut.sv tb.sv
check p16_struct_port        iverilog       iverilog  iv_sim p16_tb dut.sv tb.sv
check p16_struct_port        yosys-synth    yosys     ys_synth p16_dut dut.sv
check p16_struct_port        verilator-twin verilator vl_sim_twin p16_tb -DTWIN dut.sv tb.sv
check p16_struct_port        verilator-named-pattern verilator vl_sim p16_tb -DNAMED_PATTERN dut.sv tb.sv
check p16_struct_port        iverilog-named-pattern iverilog iv_sim p16_tb -DNAMED_PATTERN dut.sv tb.sv
check p16_struct_port        yosys-named-pattern yosys ys_synth p16_dut -DNAMED_PATTERN dut.sv

check p17_coverage_report    verilator-lcov genhtml   vl_cov_html
check p18_equivalence        eqy            eqy       eqy_dual
check p19_mutation           mcy            mcy       mcy_dual
check p20_line_monitor       sigrok         sigrok-cli vl_line_monitor
check p21_register_gen       peakrdl        peakrdl   rdl_dual
check p22_second_frontend    slang          python3   slang_dual
check p22_second_frontend    iverilog       iverilog  iv_reject_bad
check p23_style_lint         svlint         svlint    svlint_dual

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
