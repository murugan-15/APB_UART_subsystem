# Project status — APB UART

| Field | Value |
|---|---|
| Target | v1.0 release (v0.1 directed → v0.5 constrained-random + SVA → v1.0 formal + FPGA + CDC) |
| Autonomy | Level 3 |
| Mode | LEARN |
| Release cut | v1.0 |
| Current gate | **Gate 1 — Learn the block** (active) |

## Gates

| Gate | Name | State | Exit evidence |
|---|---|---|---|
| 0 | Setup and toolchain baseline (M0) | Closed (rebuilt 2026-10-10) | `make probe` exits 0 against `tb/probes/expected.txt`; tool matrix in `conventions.md` §1–2 |
| 1 | Learn the block | Active | `docs/context_note.md` (context note + learning checklist); checkpoint answered |
| 2+ | (planned with the user at Gate 1 exit) | — | — |

### Gate 0 rebuild note (2026-10-10)

The original Gate 0 commits (`90d1ec3`, `fc6c64b`, `883f661`, `571ee98`) were
never pushed and were lost when their cloud container was reclaimed. Gate 0
was rebuilt from the handoff summary in a new session:

- Toolchain rebuilt from source at the same pinned versions
  (`scripts/install_toolchain.sh`), because release tarballs are blocked
  in the cloud sandbox.
- The 15 probes were re-implemented to the same design (self-checking, dual
  property / anti-vacuity, one line per check). They are new code, not a
  copy of the originals.
- `expected.txt` was **re-measured**, not copied: **26 PASS / 13 FAIL /
  1 UNAVAIL** (40 checks), against the original 26 / 8 / 1. The check list
  differs; the new checks pin gaps found during the rebuild (Yosys has no
  `import`/`return`, Icarus has no `$error` format args, Icarus assertion
  failures exit 0). Each FAIL is a confirmed tool limit; see
  `conventions.md` §2.
- Original findings reproduced: Icarus can't run class-based TBs, Yosys
  rejects concurrent SVA and silently drops `bind`, BUG-002.
- Lesson: three Verilator FAILs and one sby FAIL in the first run were
  **probe bugs** (lint, uninitialized state at step 0). Read the log before
  recording a FAIL as a tool gap (`bug_log.md`).

## Gate 1 plan

Deliverable: `docs/context_note.md` with the context note and a learning
checklist that separates **specified facts**, **design choices**, and
**open questions**.

| # | Topic | State |
|---|---|---|
| L1 | System context (where the UART sits, who drives it) | Not started |
| L2 | APB3 protocol (setup/access phases, PREADY, PSLVERR) | Not started |
| L3 | UART frame (start, data, parity, stop; LSB first) | Not started |
| L4 | Baud generation (divisor, oversampling, error budget) | Not started |
| L5 | RX synchronizer and start-bit detection | Not started |
| L6 | FIFOs (depth, full/empty, overflow policy) | Not started |
| L7 | Registers and interrupts | Not started |
| L8 | Verification strategy (sim / SVA / formal / FPGA split) | Not started |

Checkpoint: 5 new angles on the M0 topics (vacuity, ...). The rest of the
checkpoint plan was cut off in the session handoff. **Confirm it with the
user before running the checkpoint.**

## Decisions

| ID | Decision | Date |
|---|---|---|
| D-001, D-002 | Recorded in the lost Gate 0 commits; text not recoverable from the handoff. Re-record if still relevant. | — |
| D-003 | Target v1.0, accepting outside dependencies: Vivado on an x86 host (synthesis/implementation), EDA Playground (UVM; no local UVM), Basys 3 board + sigrok-cli (hardware validation). | Gate 0 |
| D-004 | Toolchain is built from source at pinned tags via `scripts/install_toolchain.sh`; apt versions are too old and release tarballs are blocked in the cloud sandbox. | 2026-10-10 |

## Open decisions

- Async FIFO for CDC (Phase 3).
