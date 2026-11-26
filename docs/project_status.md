# Project Status

Read at the start of every session; updated at the end of every session.

```text
Project:            APB UART
Current phase/gate: 1 — Learn the block (in progress)
Target release cut: v1.0, staged v0.1 → v0.5 → v1.0 (D-003)
Active milestone:   none — Gate 1 deliverable is a context note + learning checklist in docs/
Last updated:       2026-11-26
```

## Gate checklist

| Phase | Status (done / in progress / not started / N/A / not run) | Evidence or reason |
|---|---|---|
| 0 Inspect & bound | done (2026-10-10, rebuilt same day) | Toolchain baseline M0: `make probe` matches `tb/probes/expected.txt`; release cut D-003. See "Gate 0 history" below. |
| 1 Learn | in progress | L1–L8 done; `docs/context_note.md` drafted 2026-11-26 and read by a fresh reader (10 findings, all fixed; fix diff read again); the exit checks open |
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

## Tools and structure check (per gate, D-006)

At each gate exit, confirm the tools and the repository structure that gate needs are in
place, are the right choice, and pass a probe before anything relies on them (conventions §2).
Status: pass / fail / not run / not applicable, with evidence.

| Gate | Check | Candidate tools / structure | Status |
|---|---|---|---|
| 0 | Pinned toolchain, probe baseline, repository skeleton | Verilator, Icarus, Yosys, sby, Yices, Z3; `make probe` | pass (2026-10-10) |
| 1 | Tools for the later gates chosen and probed before anything relies on them (D-011 to D-014) | uvm-verilator, mcy, eqy, svlint, slang, PeakRDL, lcov, sigrok-cli, reuse; probes p15 to p27; `make license` | pass (2026-11-15): `make probe` 48 / 20 / 0 matches the new baseline; `reuse lint` and `make check-docs` pass |
| 2 | Requirements traceable by ID | `docs/spec.md` with REQ-* IDs | not run |
| 3 | One register description generating docs and C header (D-007); board test sequencer designed (D-008) | SystemRDL + PeakRDL (`rdl/`, probed in p21); `rtl/board/` | not run |
| 4 | Verification plan names a tool per check | `docs/verification_plan.md` | not run |
| 5 | RTL lint clean on three readers | `verilator --lint-only -Wall`; slang (`scripts/slang_check.py`, p22); svlint with `.svlint.toml` (p23). Verible is not used: its binaries are release downloads, which the cloud host blocks | not run |
| 7 | Reproducible regression with seeds and coverage | `scripts/regression.py`; Verilator `--coverage` with an lcov HTML report (p17); mutation coverage with mcy (p19); sigrok line monitor (p20); UVM on Verilator (p15, D-012); covergroups through `get_inst_coverage()` (p26) | not run |
| 8 | Formal jobs per block | SymbiYosys (`formal/`); eqy for equivalence (p18) | not run |
| 9 | CI anyone can run (D-010): pinned tool image, all checks on push, Codespaces | GitHub Actions (`.github/workflows/`), GHCR image from `scripts/install_toolchain.sh`, `.devcontainer/` | not run |
| 10 | Resource, timing, bring-up evidence; written CDC review | Yosys `synth_xilinx`, openXC7, Vivado (D-002); `sigrok-cli` | not run |
| 11 | Release-ready IP package | FuseSoC `.core`, `README.md`, `CHANGELOG.md`, `LICENSE` (added, D-009), datasheet, `sw/` header and driver, version tags | not run |

## Check results (latest)

| Check | Status | Command | Evidence |
|---|---|---|---|
| Probes | pass — matches baseline (48 PASS / 20 FAIL known tool limits / 0 UNAVAIL over 68 checks), 2026-11-15, cloud host, toolchain rebuilt from `scripts/install_toolchain.sh` | `make probe` | `build/probe/results.txt`; baseline `tb/probes/expected.txt` (re-accepted 2026-11-15, D-011 to D-013); summary in `conventions.md` §2 |
| Probes, original Mac suite | pass — matches its baseline (26 PASS / 8 FAIL / 1 UNAVAILABLE), 2026-11-15, cloud host | `make probe-mac` | `build/reports/probes_mac.txt`; `tb/probes/mac_suite/README.md` |
| License headers | pass — every file, 2026-11-15 | `make license` | `reuse lint` output; `REUSE.toml` (D-014) |
| Documents agree with each other and the repository | pass, self-test 15 of 15, 2026-11-15 | `make check-docs` | `scripts/check_docs.py` output |
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
| L2 | APB3 protocol (setup/access phases, PREADY, PSLVERR) | done 2026-10-22 |
| L3 | UART frame (start, data, parity, stop; LSB first) and transmitter | done 2026-10-23 |
| L4 | Baud generation (divisor, oversampling, error budget) | done 2026-10-25 |
| L5 | RX synchronizer and start-bit detection | done 2026-10-26 |
| L6 | FIFOs (depth, full/empty, overflow policy) | done 2026-10-27 |
| L7 | Registers and interrupts | done 2026-11-01 |
| L8 | Verification strategy (sim / SVA / formal / FPGA split) | done 2026-11-02 |

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
spec and the directory scaffolding. Its probe suite is kept as a separate suite in `tb/probes/mac_suite/`; the four constructs it
alone covered were ported into the main suite on 2026-11-15 (`conventions.md` §2.3).

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

Findings of 2026-11-15 (probes p15 to p27):

- Icarus rejects an interface port anywhere in the hierarchy, and Icarus and Yosys reject named
  assignment patterns → no interfaces in RTL, struct members assigned one by one (D-011).
- A `uvm_error` leaves the exit code at 0 → a UVM verdict reads the report counts (D-012).
- svlint checks only the rules its rule file lists (an empty file checks nothing), and slang
  without its analysis pass misses a double-driven variable → every tool check keeps a run that must fail (conventions rule 18).
- Icarus accepts a variable written by `always_comb` and by a second process; Verilator warns
  (MULTIDRIVEN) and slang rejects it.
- Verilator 5.050 reports PROCASSINIT only under `-Wall` (p24). Ubuntu 24.04's 5.020 does not
  report it at all (seen by hand, not pinned by a probe) → results count only on the pinned version.
- Verilator's `get_inst_coverage()` returns bins hit over bins (37.5 for 3 of 8 in p26). IEEE
  1800-2023 §19.11 defines the weighted average over coverpoints and crosses, 41.67 for p26
  (checked 2026-11-26) → Gate 4 states coverage targets on numbers computed to the standard (O-16).

## Decisions

See `docs/decisions.md` (D-001 to D-021).

## Open decisions (mine to make)

- [x] Reset convention — D-001, 2026-10-10
- [x] FPGA flow — D-002, 2026-10-10
- [x] Target release cut — D-003, 2026-10-10
- [x] Project line — `main` (2026-10-13)
- [x] Port the four original-only probes — done 2026-11-15 (milestone M0b): mailbox p25,
      covergroup p26, FST dump p27, `--coverage` p17; the original suite stays in
      `tb/probes/mac_suite/`
- [x] Delete the original-line branch — done 2026-10-14 (the public repo then had `main` only; review branches have been pushed since, and the throwaway `ci-must-fail-twin` is still to be deleted)
- [ ] Async FIFO / separate UART clock (the only CDC content) — decide in Phase 3
- [x] Register description — D-007 (SystemRDL for docs and header, hand-written RTL), 2026-10-23
- [x] FPGA APB driver — D-008 (on-board test sequencer), 2026-10-23
- [ ] Soft CPU running the C driver on the board — revisit after v1.0
- [x] License — D-009 (Apache-2.0), 2026-10-23
- [x] CI — D-010 (own pinned toolchain image on GHCR, CI on every push, Codespaces), 2026-10-23
- [x] ASIC flow (OpenLane / SKY130) — not pursued (2026-10-23)
- [x] Interfaces in RTL — D-011 (none; packed structs on ports), 2026-11-15
- [x] UVM host — D-012 (Verilator with uvm-verilator; EDA Playground optional), 2026-11-15
- [x] Tools for the production-level checks — D-013, 2026-11-15
- [x] License headers on every file — D-014, 2026-11-15
- [x] Quality rules for every artifact and a light CI now — D-015, 2026-11-15
- [x] Conventions rule 19 (PROCASSINIT on for `rtl/`, waived for testbenches) — D-016, 2026-11-15
- [x] Copyright holder name in the SPDX headers — Ramasubbu Bala Murugan (2026-11-16)
- [x] Receiver start edge, previous sample on ticks — D-017, 2026-11-17
- [x] Verification register model from SystemRDL, in principle — D-018, 2026-11-17 (confirm at Gate 4 after a probe)
- [x] TX_OVF as a W1C INT_STATUS event with an enable — D-019, 2026-11-17 (depends on seed open decision 3)
- [x] tx_done means the transmitter is idle — D-020, 2026-11-17
- [ ] RX re-arm in a back-to-back burst — decide in Phase 3: as proposed, the receiver decides the stop
      bit at tick 153 and updates its previous-sample flop on every tick, so a far end more than 3.90 %
      fast at 8N1 (shared tick; 3.53 % at 8E1) loses the next start edge, and ±2 % at each end does not fit. Options: re-arm in
      STOP (4.58 %), the restarted RX counter (4.56 % at D = 54), or a stated lower limit (found
      2026-11-24 by a cycle model of the proposed receiver, Gate 1 checkpoint)
- [x] Basis of every requirement and evidence of every behaviour — D-021, 2026-11-25 (study material is
      overview only; enforced gate by gate from Gate 2)
- [ ] CDC sign-off has no free tool: written review plus a structural script (decide the script's
      scope with the Phase 3 clocking decision)

## Next step

The Gate 1 exit checks (PLANS.md §4).
