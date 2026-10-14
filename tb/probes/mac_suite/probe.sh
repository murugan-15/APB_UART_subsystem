#!/usr/bin/env bash
# probe.sh — run every toolchain capability probe (conventions.md §2) and write
# build/reports/probes.txt.
#
# Result per probe x tool:
#   PASS         construct works with this tool (positive probes) or the tool correctly
#                rejected/caught the deliberate error (negative probes)
#   FAIL         construct rejected or misbehaves; the log path says why
#   UNAVAILABLE  the tool or a dependency is missing; nothing was tested
#
# Exit status: the actual results are compared against the reviewed baseline
# tb/probes/expected.txt. Exit 0 if every (probe, tool) result matches it, 1 on any
# difference (a tool upgrade that breaks or newly supports a construct, a missing tool, or a
# broken probe). Without a baseline file, exit 1 if any probe FAILed.
#
# Usage: tb/probes/mac_suite/probe.sh         (called by `make probe-mac`)
#        UPDATE_BASELINE=1 tb/probes/mac_suite/probe.sh   (rewrite expected.txt from this run; review the
#                                              git diff before committing it)

set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PDIR="$ROOT/tb/probes/mac_suite"
FDIR="$PDIR/formal"
OUT="$ROOT/build/probes_mac"
RPT="$ROOT/build/reports/probes_mac.txt"
BASELINE="$PDIR/expected.txt"
FPGA_ENV="$HOME/fpga-env/bin/activate"

# Homebrew on Apple Silicon installs headers/libs under /opt/homebrew, which Apple clang does
# not search by default. Verilator's FST writer needs lz4.h from there.
VL_HOST_FLAGS=""
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"
  VL_HOST_FLAGS="-CFLAGS -I$BREW_PREFIX/include -LDFLAGS -L$BREW_PREFIX/lib"
fi

rm -rf "$OUT"
mkdir -p "$OUT" "$(dirname "$RPT")"

ROWS=""          # accumulated report rows
ACTUAL=""        # "probe tool result" lines, compared against the baseline
N_PASS=0; N_FAIL=0; N_UNAV=0

# record <probe> <tool> <result> <note> <command> <log>
record() {
  local probe=$1 tool=$2 result=$3 note=$4 cmd=$5 log=$6
  case $result in
    PASS) N_PASS=$((N_PASS + 1)) ;;
    FAIL) N_FAIL=$((N_FAIL + 1)) ;;
    *)    N_UNAV=$((N_UNAV + 1)) ;;
  esac
  printf '%-24s %-10s %-12s %s\n' "$probe" "$tool" "$result" "$note"
  ACTUAL+="$probe $tool $result"$'\n'
  ROWS+=$(printf '%-24s %-10s %-12s %s\n    cmd: %s\n    log: %s' \
          "$probe" "$tool" "$result" "$note" "$cmd" "${log#"$ROOT"/}")$'\n'
}

# run_cmd <workdir> <log> <command...>: run in workdir, append all output to log, return status
run_cmd() {
  local wd=$1 log=$2; shift 2
  echo "\$ $*" >> "$log"
  (cd "$wd" && eval "$@") >> "$log" 2>&1
}

# ---------------------------------------------------------------------------------------
# Simulation probes
# sim_probe <probe-id> <tool> <top> "<sources>" "<extra build flags>" <expect: pass|elab_fail> [elab-fail grep]
# ---------------------------------------------------------------------------------------
sim_probe() {
  local id=$1 tool=$2 top=$3 srcs=$4 flags=$5 expect=$6 errpat=${7:-}
  local wd="$OUT/$tool/$id"; mkdir -p "$wd"
  local log="$wd/log.txt"; : > "$log"
  local bcmd rcmd
  case $tool in
    verilator)
      bcmd="verilator --binary -j 0 --timing --assert -Wall -Wno-fatal -Werror-USERERROR $VL_HOST_FLAGS -I$PDIR $flags --top-module $top -Mdir $wd/obj $srcs"
      rcmd="$wd/obj/V$top" ;;
    icarus)
      bcmd="iverilog -g2012 -Wall -I$PDIR $flags -s $top -o $wd/sim.vvp $srcs"
      rcmd="vvp -n $wd/sim.vvp" ;;
  esac
  [ -n "${RUN_ARGS:-}" ] && rcmd="$rcmd $RUN_ARGS"

  if ! run_cmd "$wd" "$log" "$bcmd"; then
    if [ "$expect" = elab_fail ]; then
      if grep -q "$errpat" "$log"; then
        record "$id" "$tool" PASS "illegal parameter rejected at elaboration with the intended message" "$bcmd" "$log"
      else
        record "$id" "$tool" FAIL "build failed, but not with the intended \$error message" "$bcmd" "$log"
      fi
    else
      record "$id" "$tool" FAIL "build failed: $(grep -m1 -E '%Error|error|sorry' "$log" | sed "s|$PDIR/||" | cut -c1-90)" "$bcmd" "$log"
    fi
    return
  fi
  if [ "$expect" = elab_fail ]; then
    record "$id" "$tool" FAIL "illegal parameter was NOT rejected (\$error ignored)" "$bcmd" "$log"
    return
  fi

  local rc=0
  run_cmd "$wd" "$log" "$rcmd" || rc=$?
  if grep -q "Unable to communicate with SAT solver" "$log"; then
    record "$id" "$tool" UNAVAILABLE "built, but runtime SMT solver missing ($(grep -o 'Tried: .*' "$log" | head -1))" "$bcmd && $rcmd" "$log"
  elif [ $rc -eq 0 ] && grep -q "PROBE PASS" "$log" && ! grep -q "PROBE FAIL" "$log"; then
    record "$id" "$tool" PASS "$(grep -h -m1 -E '^INFO|PROBE PASS' "$log")" "$bcmd && $rcmd" "$log"
  else
    record "$id" "$tool" FAIL "built, but run/self-check failed (exit $rc)" "$bcmd && $rcmd" "$log"
  fi
  # Leave the work dir in place for post-checks (coverage / dump format).
}

echo "== Simulation probes =="
for tool in verilator icarus; do
  for p in p01_class_queue_mailbox p02_randomize p03_covergroup p04_sva_concurrent p05_bind p09_assume_macro; do
    sim_probe "$p" "$tool" "$p" "$PDIR/$p.sv" "" pass
  done
  sim_probe p06_param_ok  "$tool" p06_param_check "$PDIR/p06_param_stub.sv $PDIR/p06_param_check.sv" "-DP06_DEPTH=4" pass
  sim_probe p06_param_bad "$tool" p06_param_check "$PDIR/p06_param_stub.sv $PDIR/p06_param_check.sv" "-DP06_DEPTH=3" elab_fail "power of two"
done

# UVM: library not installed; per the M0 card nothing is downloaded.
if [ -n "${UVM_HOME:-}" ] && [ -f "$UVM_HOME/src/uvm_pkg.sv" ]; then
  record p_uvm verilator UNAVAILABLE "UVM_HOME set but no UVM probe written yet" "-" "-"
else
  record p_uvm verilator UNAVAILABLE "UVM library not installed (UVM_HOME unset); not downloaded per M0 scope" "-" "-"
fi

# ---------------------------------------------------------------------------------------
# P07 — Verilator line/toggle coverage flow
# ---------------------------------------------------------------------------------------
echo "== Code coverage probe =="
sim_probe p07_code_coverage verilator p07_code_coverage "$PDIR/p07_code_coverage.sv" "--coverage" pass
wd="$OUT/verilator/p07_code_coverage"; log="$wd/log.txt"
covcmd="verilator_coverage --annotate $wd/annotated <coverage.dat>"
dat=$(find "$wd" -name 'coverage.dat' -not -path '*/obj/*' | head -1)
if [ -z "$dat" ]; then
  record p07_cov_report verilator FAIL "no coverage.dat written by the run" "$covcmd" "$log"
elif ! run_cmd "$wd" "$log" "verilator_coverage --annotate $wd/annotated $dat"; then
  record p07_cov_report verilator FAIL "verilator_coverage --annotate failed" "$covcmd" "$log"
elif grep -rqE '^%0+ ' "$wd/annotated"; then
  record p07_cov_report verilator PASS "coverage.dat annotated; never-taken branch shows count 0" "verilator_coverage --annotate $wd/annotated $dat" "$log"
else
  record p07_cov_report verilator FAIL "annotation produced but no zero-count line found" "verilator_coverage --annotate $wd/annotated $dat" "$log"
fi

# ---------------------------------------------------------------------------------------
# P08 — waveform dump format (FST = binary header starting with byte 0x00; VCD = text '$')
# ---------------------------------------------------------------------------------------
echo "== Waveform dump probes =="
check_fst() { # <probe-id> <tool> <file> <cmd> <log>
  local first
  if [ ! -s "$3" ]; then
    record "$1" "$2" FAIL "no dump file written" "$4" "$5"; return
  fi
  first=$(head -c 1 "$3" | xxd -p)
  if [ "$first" = "00" ]; then
    record "$1" "$2" PASS "FST written ($(wc -c < "$3" | tr -d ' ') bytes)" "$4" "$5"
  else
    record "$1" "$2" FAIL "dump file is not FST (first byte 0x$first)" "$4" "$5"
  fi
}
RUN_ARGS="+dump=p08.fst" sim_probe p08_wave_dump verilator p08_wave_dump "$PDIR/p08_wave_dump.sv" "--trace-fst" pass
check_fst p08_fst verilator "$OUT/verilator/p08_wave_dump/p08.fst" "verilator --binary --trace-fst ... && Vp08_wave_dump +dump=p08.fst" "$OUT/verilator/p08_wave_dump/log.txt"
RUN_ARGS="-fst +dump=p08.fst" sim_probe p08_wave_dump icarus p08_wave_dump "$PDIR/p08_wave_dump.sv" "" pass
check_fst p08_fst icarus "$OUT/icarus/p08_wave_dump/p08.fst" "iverilog ... && vvp -n sim.vvp -fst +dump=p08.fst" "$OUT/icarus/p08_wave_dump/log.txt"

# ---------------------------------------------------------------------------------------
# P06 — parameter $error under Yosys (synthesis read must reject illegal DEPTH too)
# ---------------------------------------------------------------------------------------
echo "== Yosys elaboration probes =="
yosys_param() { # <probe-id> <depth> <expect: pass|elab_fail>
  local wd="$OUT/yosys/$1"; mkdir -p "$wd"; local log="$wd/log.txt"; : > "$log"
  local cmd="yosys -p 'read_verilog -sv $PDIR/p06_param_stub.sv; hierarchy -top p06_param_stub -chparam DEPTH $2; proc'"
  if run_cmd "$wd" "$log" "$cmd"; then
    if [ "$3" = pass ]; then record "$1" yosys PASS "DEPTH=$2 elaborated" "$cmd" "$log"
    else record "$1" yosys FAIL "illegal DEPTH=$2 was NOT rejected (\$error ignored)" "$cmd" "$log"; fi
  else
    if [ "$3" = pass ]; then record "$1" yosys FAIL "legal DEPTH=$2 failed to elaborate" "$cmd" "$log"
    elif grep -q "power of two" "$log"; then record "$1" yosys PASS "illegal DEPTH=$2 rejected with the intended message" "$cmd" "$log"
    else record "$1" yosys FAIL "failed, but not with the intended \$error message" "$cmd" "$log"; fi
  fi
}
yosys_param p06_param_ok 4 pass
yosys_param p06_param_bad 3 elab_fail

# ---------------------------------------------------------------------------------------
# Formal probes (sby, from ~/fpga-env)
# formal_probe <probe-id> <sby-file> <task> <expected sby status: PASS|FAIL> [assert label]
#   For an expected FAIL with a label, the counterexample must hit that assertion; failing on
#   a different property is a FAIL of the probe (wrong reason).
# ---------------------------------------------------------------------------------------
echo "== Formal probes =="
formal_probe() {
  local id=$1 sby=$2 task=$3 want=$4 label=${5:-}
  local base; base=$(basename "$sby" .sby)
  local prefix="$OUT/formal/$base"; mkdir -p "$OUT/formal"
  local wd="${prefix}_$task" log="$OUT/formal/${base}_$task.log"; : > "$log"
  local cmd="sby -f --prefix $prefix $sby $task"
  if [ -z "${SBY_OK:-}" ]; then
    record "$id" sby UNAVAILABLE "sby not found ($FPGA_ENV missing?)" "$cmd" "-"; return
  fi
  run_cmd "$FDIR" "$log" "$cmd"
  local status; status=$(awk '{print $1; exit}' "$wd/status" 2>/dev/null)
  status=${status:-NONE}
  if [ "$status" = FAIL ] && [ "$want" = FAIL ] && [ -n "$label" ] \
       && ! grep -qE "Assert failed in .*: $label\$" "$log"; then
    record "$id" sby FAIL "sby FAIL, but not on the intended assertion $label" "$cmd" "$log"
  elif [ "$status" = "$want" ]; then
    if [ "$want" = FAIL ]; then
      note="sby FAIL as intended on ${label:-a property}; trace: $(cd "$wd" && ls engine_*/trace*.vcd 2>/dev/null | head -1)"
    else
      note="sby PASS"
    fi
    record "$id" sby PASS "$note" "$cmd" "$log"
  elif [ "$want" = FAIL ] && [ "$status" = ERROR ] && grep -q "was asserted in frame" "$log" \
       && grep -qi "solver .* not found" "$log"; then
    record "$id" sby UNAVAILABLE "abc found the bug ($(grep -o 'asserted in frame [0-9]*' "$log" | head -1)) but CEX trace generation needs an SMT solver -> sby ERROR" "$cmd" "$log"
  elif [ "$status" = ERROR ] && grep -qi "solver .* not found" "$log"; then
    record "$id" sby UNAVAILABLE "SMT solver missing (sby status ERROR)" "$cmd" "$log"
  else
    record "$id" sby FAIL "sby status $status, expected $want" "$cmd" "$log"
  fi
}

if [ -f "$FPGA_ENV" ]; then
  # shellcheck disable=SC1090
  source "$FPGA_ENV"
fi
command -v sby >/dev/null 2>&1 && SBY_OK=1

formal_probe f01_prove_pdr     "$FDIR/f01_past_assert.sby"    prove_pdr    PASS
formal_probe f01_bmc_abc       "$FDIR/f01_past_assert.sby"    bmc_abc      PASS
formal_probe f01_bmc_smtbmc    "$FDIR/f01_past_assert.sby"    bmc_smtbmc   PASS
formal_probe f01_cover_smtbmc  "$FDIR/f01_past_assert.sby"    cover_smtbmc PASS
formal_probe f01_bug_pdr       "$FDIR/f01_past_assert.sby"    bug_pdr      FAIL a_bug
formal_probe f01_noassume_pdr  "$FDIR/f01_past_assert.sby"    noassume_pdr FAIL a_range
formal_probe f02_sva_prove     "$FDIR/f02_sva_concurrent.sby" prove_pdr    PASS
formal_probe f02_sva_bug       "$FDIR/f02_sva_concurrent.sby" bug_pdr      FAIL a_seq
formal_probe f03_bind_prove    "$FDIR/f03_bind.sby"           prove_pdr    PASS
formal_probe f03_bind_bug      "$FDIR/f03_bind.sby"           bug_pdr      FAIL a_bug

# ---------------------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------------------
{
  echo "Capability probe report (conventions.md §2)"
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')   Host: $(uname -sm)"
  echo "Command:   make probe  (scripts/probe.sh)"
  echo
  echo "Tool versions:"
  echo "  $(verilator --version 2>&1 | head -1)"
  echo "  $(iverilog -V 2>&1 | head -1)"
  echo "  $(yosys -V 2>&1 | head -1)"
  if [ -n "${SBY_OK:-}" ]; then echo "  sby: $(command -v sby)"; else echo "  sby: not found"; fi
  for s in yices-smt2 z3 boolector bitwuzla; do
    printf '  %-11s %s\n' "$s:" "$(command -v $s || echo 'not found')"
  done
  echo
  echo "Summary: PASS=$N_PASS FAIL=$N_FAIL UNAVAILABLE=$N_UNAV"
  echo
  printf '%-24s %-10s %-12s %s\n' PROBE TOOL RESULT NOTE
  printf '%s' "$ROWS"
} > "$RPT"

echo
echo "Summary: PASS=$N_PASS FAIL=$N_FAIL UNAVAILABLE=$N_UNAV  -> ${RPT#"$ROOT"/}"

# ---------------------------------------------------------------------------------------
# Baseline comparison
# ---------------------------------------------------------------------------------------
ACT_FILE="$OUT/actual.txt"
printf '%s' "$ACTUAL" | sort > "$ACT_FILE"

if [ -n "${UPDATE_BASELINE:-}" ]; then
  {
    echo "# Expected capability-probe results: <probe> <tool> <PASS|FAIL|UNAVAILABLE>"
    echo "# FAIL here means a known, recorded tool limitation (conventions.md §2), not a broken probe."
    echo "# Regenerate with: UPDATE_BASELINE=1 make probe   (review the diff before committing)"
    cat "$ACT_FILE"
  } > "$BASELINE"
  echo "Baseline rewritten: ${BASELINE#"$ROOT"/}"
  exit 0
fi

if [ ! -f "$BASELINE" ]; then
  echo "No baseline (${BASELINE#"$ROOT"/}); exit status reflects FAIL count only."
  [ "$N_FAIL" -eq 0 ]
  exit
fi

if diff <(grep -v '^#' "$BASELINE" | sort) "$ACT_FILE" > "$OUT/baseline.diff"; then
  echo "Baseline: all results match ${BASELINE#"$ROOT"/} (known limitations unchanged)"
  echo "Baseline: MATCH" >> "$RPT"
  exit 0
else
  echo "Baseline: RESULTS CHANGED vs ${BASELINE#"$ROOT"/}  (< expected, > actual):"
  grep -E '^[<>]' "$OUT/baseline.diff"
  { echo; echo "Baseline: MISMATCH"; grep -E '^[<>]' "$OUT/baseline.diff"; } >> "$RPT"
  exit 1
fi
