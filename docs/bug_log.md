# Bug log

Format: ID · found in · symptom · root cause · fix · guard (what stops it recurring).

## BUG-001 — p04 testbench race (M0)

- **Found in:** M0 probe p04 (original Gate 0).
- **Symptom:** the same TB + DUT gave different pipeline results in
  Verilator and Icarus.
- **Root cause:** the TB drove the DUT input with a *blocking* assignment at
  `@(posedge clk)`. Whether the DUT's `always_ff` read the old or new value
  depended on process scheduling order, which the LRM leaves to the
  simulator. That is a race.
- **Fix:** drive with nonblocking assignments at posedge (or blocking at
  negedge) and check outputs at the opposite edge.
- **Guard:** p04 checks the race-free convention in both simulators;
  `conventions.md` §3 makes it the TB rule.

## BUG-002 — `-Wno-fatal` hides elaboration `$error` in Verilator (M0)

- **Found in:** M0 probe p08 (original Gate 0); re-confirmed 2026-10-10
  with Verilator 5.050 (check `p08_elab_error verilator-wnofatal` = FAIL).
- **Symptom:** an illegal parameter (W=1) that must be rejected elaborates
  successfully when Verilator runs with `-Wno-fatal`.
- **Root cause:** Verilator reports elaboration-time `$error` as
  `%Warning-USERERROR`, not as an error. It is fatal only because warnings
  are fatal by default; `-Wno-fatal` turns it into a printed message and
  elaboration continues.
- **Fix:** never use a blanket `-Wno-fatal` in project flows. Silence
  specific lint codes locally with `/* verilator lint_off CODE */` if needed.
- **Guard:** p08 keeps both checks (`verilator` must PASS,
  `verilator-wnofatal` stays FAIL in the baseline), so a change in
  Verilator's behaviour shows up as a baseline diff.

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
