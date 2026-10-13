# Project Status

Read at the start of every session; updated at the end of every session.

```text
Project:            APB UART
Current phase/gate: 1 — Learn the block (in progress)
Current mode:       LEARN
Autonomy level:     3
Target release cut: v1.0, staged v0.1 → v0.5 → v1.0 (D-003)
Active milestone:   none — Gate 1 deliverable is a context note + learning checklist in docs/
Last updated:       2026-10-13
```

## Gate checklist

| Phase | Status (done / in progress / not started / N/A / not run) | Evidence or reason |
|---|---|---|
| 0 Inspect & bound | done (2026-10-10, rebuilt same day) | Toolchain baseline M0: `make probe` matches `tb/probes/expected.txt`; release cut D-003. See "Gate 0 history" below. |
| 1 Learn | in progress | L1 done; L2–L8 open (table below) |
| 2 Requirements | not started | Input: `docs/uart_spec_seed.md` |
| 3 Architecture | not started | |
| 4 Verification plan | not started | |
| 5 Stage 1 RTL | not started | |
| 6 Stage 2 RTL | not started | |
| 7 Stage 3 verification | not started | |
| 8 Assertions & formal | not started | |
| 9 Automation & CI | not started | |
| 10 Synth / timing / CDC / FPGA | not started | |
| 11 Readiness review | not started | |
| 12 Design defense and rebuild | not started | |

## Check results (latest)

| Check | Status | Command | Evidence |
|---|---|---|---|
| Probes | pass — matches baseline (26 PASS / 13 FAIL known tool limits / 1 UNAVAIL UVM), 2026-10-10, cloud host | `make probe` | `build/probe/results.txt`; baseline `tb/probes/expected.txt`; summary in `conventions.md` §2 |
| Lint | not run | `make lint` (not implemented) | |
| Regression | not run | `make regression` (not implemented) | |
| Formal | not run | `make formal` (not implemented) | |
| Synthesis | not run | `make synth` (not implemented) | |
| Timing | not run | — | |
| FPGA bring-up | not run | — | |

## Gate 1 — learn the block

Deliverable: `docs/context_note.md` with the context note and a learning checklist that
separates **specified facts**, **design choices**, and **open questions**.

| # | Topic | State |
|---|---|---|
| L1 | System context (where the UART sits, who drives it) | done 2026-10-12 |
| L2 | APB3 protocol (setup/access phases, PREADY, PSLVERR) | next |
| L3 | UART frame (start, data, parity, stop; LSB first) | not started |
| L4 | Baud generation (divisor, oversampling, error budget) | not started |
| L5 | RX synchronizer and start-bit detection | partly (synchronizer depth, multi-bit CDC) |
| L6 | FIFOs (depth, full/empty, overflow policy) | not started |
| L7 | Registers and interrupts | not started |
| L8 | Verification strategy (sim / SVA / formal / FPGA split) | not started |

Gate 1 checkpoint: a fresh variant of each M0 topic plus L1–L8 explained cold; any topic
still weak goes on a revisit list at Gate 2 entry.

## Gate 0 history

Two implementations of Gate 0 exist:

- **Original line** (Mac host, 2026-10-10): `90d1ec3` baseline template, `fc6c64b` M0 probes,
  `883f661` solvers + baseline, `571ee98` Gate 0 close + D-003. Pushed later to a separate
  branch (history rewritten 2026-10-13; tip `f58b124`).
  Its probe set was measured as 26 PASS / 8 FAIL / 1 UNAVAILABLE.
- **Rebuilt line** (cloud host, this branch): built from the handoff summary when the original
  was believed lost. Toolchain built from source at the same pinned versions (D-004). Probes
  re-implemented (new code, same design) and re-measured: 26 PASS / 13 FAIL / 1 UNAVAIL over
  40 checks; the extra checks pin gaps found during the rebuild (Yosys has no
  `import`/`return`, Icarus has no `$error` format args, Icarus assertion failures exit 0).

`main` is the project line (decided 2026-10-13). From the original line it adopted the decision
log (D-001 to D-003), `conventions.md` §3–§8, the original BUG-001/BUG-002 entries, the seed
spec and the directory scaffolding. Its probe suite was not merged; four constructs it covered
are not yet probed here (`conventions.md` §2.3) — see open decisions.

Lesson from the rebuild: three Verilator FAILs and one sby FAIL in the first run were **probe
bugs** (lint, uninitialized state at step 0). Read the log before recording a FAIL as a tool gap.

## Key M0 findings that affect later phases

- SMT solvers are a hard dependency: Verilator `randomize()` needs `z3`; sby `smtbmc`, cover
  and CEX traces need `yices-smt2`. CI must install them too.
- Yosys rejects `import` and `return` → package-qualified names, function-name assignment.
- Yosys silently drops `bind` → formal checkers are instantiated, never bound.
- Yosys rejects concurrent SVA → formal uses immediate assertions only (§5).
- Verilator reports elaboration `$error` as a warning → `-Werror-USERERROR`, no blanket
  `-Wno-fatal` (BUG-002).
- Icarus cannot run class / SVA / bind / constrained-random TBs, and a failing assertion does not
  change its exit code → Icarus is for plain directed portability benches only.

## Decisions

See `docs/decisions.md` (D-001 to D-005).

## Open decisions (mine to make)

- [x] Reset convention — D-001, 2026-10-10
- [x] FPGA flow — D-002, 2026-10-10
- [x] Target release cut — D-003, 2026-10-10
- [x] Project line — `main` (2026-10-13)
- [ ] Port the four original-only probes (classes + mailbox, covergroup, `--coverage`, FST
      dump) into `tb/probes/` and re-baseline (proposed milestone M0b; needed before v0.5 work)
- [ ] Delete the original-line branch once this merge is accepted
- [ ] Async FIFO / separate UART clock (the only CDC content) — decide in Phase 3

## Next step

Gate 1, L2 (APB3): one write with a wait state cycle by cycle; why APB has a setup phase.
