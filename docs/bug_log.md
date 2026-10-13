# Bug Log

Real bugs only, appended at the end of every DEBUG-mode resolution. Never invent or
embellish an entry.

```text
### BUG-001 — <short title>
Date:            YYYY-MM-DD
Found by:        <directed test / random seed N / assertion ID / formal CEX / lint / review>
Reproduce:       <exact command, seed, config>
Symptom:         <what was observed>
Evidence:        <waveform signals + cycle/time, log lines>
Hypothesis:      <initial theory and why it fit>
Root cause:      <actual cause>
Classification:  <DUT / testbench / assertion / harness / script / tool>
Fix:             <what changed, commit hash>
Regression:      <what was re-run, result>
Prevention:      <assertion / test / coverage point added so it can't recur silently>
Lesson:          <one line>
```

### BUG-001 — Concurrent-SVA probe: stimulus race made a true property fire
Date:            2026-10-10
Found by:        Self-check in probe p04 (good property expected silent)
Reproduce:       `make probe` at the pre-fix revision of tb/probes/p04_sva_concurrent.sv (Verilator 5.050)
Symptom:         `INFO: good_fails=3 bad_fails=3` — the property that holds by construction
                 (`$rose(req) |-> ##1 ack`) fired once per req pulse.
Evidence:        Log build/probes/verilator/p04_sva_concurrent/log.txt. Good and bad properties
                 fired the same number of times (3 = number of req pulses), which fits "ack
                 never rises". No waveform was dumped, so this evidence is indirect.
Hypothesis:      `ack <= req` was in `always @(negedge clk)` while the stimulus also changed
                 `req` right after `@(negedge clk)`. Both processes wake on the same negedge;
                 if the stimulus clears req first, ack samples 0 and never rises.
Root cause:      Race between two processes triggered by the same event (testbench bug).
Classification:  testbench
Fix:             `ack` became a posedge flop (`always @(posedge clk) ack <= req;`), which is the
                 realistic DUT shape: stimulus changes on negedge, design samples on posedge.
                 Uncommitted at time of writing (M0 commit).
Regression:      `make probe`: p04 verilator `good_fails=0 bad_fails=3` → PASS.
Prevention:      Probe keeps a deliberately false property alongside the true one, so both
                 "never fires" and "always fires" are caught.
Lesson:          Drive stimulus and sample DUT on opposite edges, or use NBAs from a clocking
                 block; never let two processes race on the same edge.

### BUG-002 — Probe script masked an elaboration $error (`-Wno-fatal`)
Date:            2026-10-10
Found by:        Negative probe p06_param_bad (illegal DEPTH must fail elaboration)
Reproduce:       `verilator --binary -Wall -Wno-fatal ... -DP06_DEPTH=3 p06_param_stub.sv p06_param_check.sv`
Symptom:         Illegal DEPTH=3 built and ran; probe reported "$error ignored".
Evidence:        Log line `%Warning-USERERROR: p06_param_stub.sv:15:5: ... DEPTH must be a power of two`
                 followed by a successful C++ build.
Hypothesis:      Verilator reports elaboration `$error` as the USERERROR *warning*; `-Wno-fatal`
                 makes all warnings non-fatal.
Root cause:      Script flag choice (`-Wall -Wno-fatal` to keep TB lint noise non-fatal).
Classification:  script
Fix:             Added `-Werror-USERERROR` to the Verilator build line in scripts/probe.sh.
Regression:      `make probe`: p06_param_bad verilator → PASS (rejected with the intended message);
                 p06_param_ok still PASS.
Prevention:      p06_param_bad stays in `make probe`; the same flag must go into `make sim`/`make lint`.
Lesson:          A blanket "warnings non-fatal" flag can turn a design-intent error into a
                 warning. Make specific codes fatal again.

## Notes on the rebuilt line (2026-10-13)

BUG-001 and BUG-002 above are the original entries, with their evidence, from the original
line's probe suite. While the original was believed lost, the rebuilt line carried
reconstructed summaries of the same two bugs; those summaries were replaced by the originals
on 2026-10-13. In this repo's probe suite the same lessons are pinned by:

- BUG-001 (race between processes on one edge): p04 checks the race-free drive/sample
  convention in both simulators; `conventions.md` §2.2 rule 5.
- BUG-002 (`-Wno-fatal` hides elaboration `$error`): p08 keeps `verilator` PASS and
  `verilator-wnofatal` FAIL in `expected.txt`, so a change in Verilator's behaviour shows up
  as a baseline diff; `conventions.md` §2.2 rule 4.

## Rebuild findings (2026-10-10, not RTL bugs)

These came up while rebuilding Gate 0. They're probe or flow mistakes, not
tool gaps. Recorded so the lesson is kept.

- **Probe TBs must be Verilator lint-clean.** p01/p05/p06 first failed under
  Verilator because of `WIDTHEXPAND` (2/9-bit signal into a 32-bit task
  argument) and `IMPLICITSTATIC` (initializers on variables declared in an
  `initial` block). Verilator makes lint warnings fatal by default, so a FAIL
  can be a TB problem and not a tool gap. Fix: explicit casts, and no
  initializers on procedural-block variables. Rule: read the log before
  recording any FAIL as a tool limitation.
- **Icarus elaboration `$error` takes a single string only.** The first p08
  version used a format argument (`%0d`) and Icarus rejected it with
  "sorry: ... single string argument", for a different reason than intended.
  The probe now uses a single string and pins the format-args gap as its own
  check (`iverilog-fmtargs`).
