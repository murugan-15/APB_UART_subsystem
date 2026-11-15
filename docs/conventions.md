# Conventions — APB UART

Every rule below is backed by a probe in `tb/probes/`; `make probe` re-checks
them against `tb/probes/expected.txt`. If the baseline moves, a rule here
may no longer hold. Re-read the affected section before running `make probe-accept`.

Decided once, reused across projects. A project may override an item only by recording the
reason in `docs/decisions.md`. Items marked **PROPOSED** are awaiting approval.

## 1. Toolchain

### 1.1 Cloud host (verified 2026-10-10; extended 2026-11-15, D-013)

Built from source at pinned tags by `scripts/install_toolchain.sh` (`make toolchain`, D-004)
into `/opt/eda` (the Makefile puts `/opt/eda/bin` on `PATH`).

| Tool | Version | Role |
|---|---|---|
| Verilator | 5.050 | Primary simulator (`--binary --timing --assert`), lint |
| Icarus Verilog | 13.0 | Second simulator, for plain-RTL directed tests only (see gaps) |
| Yosys | 0.69 | Synthesis check, formal front end |
| SymbiYosys (sby) | 0.69 | Formal driver (BMC, prove) |
| Yices | 2.7.0 | SMT solver for sby `smtbmc` (BMC, k-induction, traces) |
| Z3 | 5.1.0 | SMT solver Verilator needs at runtime for `randomize()` |
| uvm-verilator | uvm-2020-3.2 | UVM 2020 library with a Verilator DPI backend, source only (D-012) |
| mcy | 0.69 | Mutation coverage: does the testbench catch planted bugs? (command-line tool only) |
| eqy | 0.69 | Equivalence checking of two versions of a block |
| svlint | 0.9.5 | Rule-based style lint with the project rule file `.svlint.toml` |
| slang (pyslang) | 12.1.0 | Second SystemVerilog front end, through `scripts/slang_check.py` |
| PeakRDL | 1.5.0 (regblock 1.3.1, cheader 1.1.0, html 2.12.2, markdown 1.0.3; systemrdl-compiler 1.33.0) | Register docs, C header and a reference register block from SystemRDL (D-007) |
| lcov | 2.0 (Ubuntu 24.04 package) | HTML coverage report from Verilator's coverage data |
| sigrok-cli | 0.7.2 (Ubuntu 24.04 package) | UART decoder used as an independent line monitor, in simulation and at bring-up |
| reuse | 6.3.0 | SPDX / license header check (`make license`) |
| ruff | 0.17.5 | Python lint for `scripts/` (light CI, D-015) |
| shellcheck | 0.9.0 (Ubuntu 24.04 package) | Shell lint for `scripts/` (light CI, D-015) |
| FuseSoC, Edalize | 2.4.7, 0.6.8 | IP packaging (Gate 11). Installed; add a probe before the first `.core` file |
| WaveDrom | 2.0.3 | Timing diagrams from text. Installed; add a probe before the first diagram |

The Python tools are pinned in `requirements-tools.txt`; lcov, sigrok-cli and gawk come from apt.
`scripts/install_toolchain.sh` skips a tool that is already at its pinned version and exits
nonzero if any step fails.

Probe baseline: **48 PASS / 20 FAIL / 0 UNAVAIL** (68 checks, 27 probes, after the second reader's
review of 2026-11-15 added a Verilator check to p22 and made p15, p19, p21, p22, p23 and p26 assert
what this file quotes; 47 / 20 / 0 over 67 checks after milestone M0b added p25 to p27 the same
day; before M0b 43 / 17 / 0 over 60 checks; re-accepted 2026-11-15
when D-011 to D-013 added p16 to p23 and turned p15 from UNAVAIL into three checks, 40 / 17 / 0
over 57 checks, and again the same day when p24 gave rules 7 and 19 a probe. Until then:
26 / 13 / 1 over 40 checks). Every FAIL below is a confirmed tool limitation (log read, cause
known), not a probe bug.

### 1.2 Mac host (original line, verified 2026-10-10)

Same pinned versions where they overlap, installed with Homebrew.

Host: Apple Silicon Mac, macOS 26.6.1, Homebrew 6.0.22.

| Purpose | Tool | Version | How it is run |
|---|---|---|---|
| Primary simulation + lint | Verilator | 5.050 | `make sim`, `make lint` |
| Secondary simulation (portability check) | Icarus Verilog | 13.0 | `make sim SIM=icarus` |
| Formal | Yosys + SymbiYosys (`sby`) | Yosys 0.69+post | `source ~/fpga-env/bin/activate && make formal` |
| SMT solvers | Yices 2 (`yices-smt2`, sby default for `smtbmc`, cover, CEX traces); Z3 (Verilator `randomize()` runtime solver) | Yices 2.7.0, Z3 5.1.0 (Homebrew) | called by `sby` / Verilator-built binaries; must be on `PATH` |
| Synthesis (area/resources) | Yosys `synth_xilinx` | 0.69+post | `make synth` |
| Python automation | Python | 3.14.7 | `scripts/*.py` (in `~/fpga-env` when FPGA/formal tools are needed) |
| FPGA flow helpers | Apio | in `~/fpga-env` | see §6 |
| Waveforms | Surfer | — | open `build/sim/*.fst` / `*.vcd` |
| Board-level capture | `sigrok-cli` | — | UART line capture + protocol decode during bring-up |
| Target hardware | Digilent Basys 3 (Artix-7 XC7A35T) | — | see §6 |

Scripts must activate `~/fpga-env` themselves when they call `sby`, `apio`, or other tools
installed there, and must fail with a clear message if the environment is missing.

---

## 2. Capability probes and the rules that follow

### 2.1 Support matrix (cloud host, `tb/probes/` on this branch)

| Feature | Verilator | Icarus | Yosys / sby | Probe |
|---|---|---|---|---|
| enum / packed struct / always_ff / always_comb / unique case | ✅ | ✅ | ✅ synth | p01 |
| Interface + modports (internal to the RTL) | ✅ | ❌ syntax error on interface ports | ✅ synth | p02 |
| Package parameters / typedef / function, `$clog2`, packed 2-D ports, generate-for | ✅ | ✅ | ✅ only in the portable form (below) | p03 |
| `return` in a function | ✅ | ✅ | ❌ syntax error | p03 |
| `import pkg::*` (header, body or file scope) | ✅ | ✅ | ❌ syntax error | p03 |
| Race-free NBA drive / opposite-edge check | ✅ | ✅ | — | p04 |
| Classes (virtual / pure virtual / inheritance / queues) | ✅ | ❌ `pure virtual` rejected | — | p05 |
| Constrained random (`rand`, constraints, `inside`, `randomize() with`) | ✅ (needs z3) | ❌ unsupported | — | p06 |
| Immediate assert action blocks | ✅ | ✅ | — | p07 |
| Failing assertion → nonzero exit | ✅ | ❌ prints ERROR, exits 0 | — | p07 |
| Elaboration `$error` in generate (single string) | ✅ (fatal by default) | ✅ | ✅ | p08 |
| Elaboration `$error` with format args | ✅ | ❌ "single string argument" | — | p08 |
| `$error` under `-Wno-fatal` | ❌ becomes a warning (BUG-002) | — | — | p08 |
| Concurrent SVA in sim (`\|-> ##N`) | ✅ correct counts | ❌ syntax error | — | p09 |
| Concurrent SVA in formal | — | — | ❌ syntax error (no Verific) | p10 |
| Immediate asserts + `$past` + `f_past_valid` in formal | — | — | ✅ incl. VCD trace | p11 |
| `bind` | ✅ | ❌ syntax error | ❌ **silently dropped** | p12 |
| `ASSUME` macro (assume in formal / assert in sim) | ✅ fires on illegal stimulus | — | ✅ load-bearing | p13 |
| BMC depth vs unbounded (abc pdr) | — | — | ✅ behaves as theory says | p14 |
| UVM 2020 test with the DPI layer (uvm-verilator) | ✅ 0 warnings, 0 errors | — | — | p15 |
| A `uvm_error` → nonzero exit | ❌ exits 0; the report counts show it | — | — | p15 |
| Packed struct (package typedef) on a module port | ✅ | ✅ | ✅ synth | p16 |
| Named assignment pattern `'{member: value}` | ✅ | ❌ syntax error | ❌ syntax error | p16 |
| A variable written by `always_comb` and by a second process (illegal: Verilator's message names IEEE 1800-2023 9.2.2.2; the clause itself has not been read, the standard is not among the project's references) | ✅ rejected, MULTIDRIVEN | ❌ accepted silently | — | p22 (slang rejects it, but only with its analysis pass) |
| Initializer on a variable declared in a procedural block (static: set once) | ✅ rejected, IMPLICITSTATIC | — | — | p24 |
| Implicit width extension | ✅ rejected, WIDTHEXPAND | — | — | p24 |
| Declaration initializer on a variable a process also assigns | accepted by default; rejected under `-Wall` (PROCASSINIT) | — | — | p24 |
| Classes with a `mailbox` between two processes | ✅ | ❌ syntax error | — | p25 |
| `covergroup` / `coverpoint` / `cross`, queried with `get_inst_coverage()` | ✅ 37.5 after one sample (3 of the 8 bins), then 100. Whether IEEE 1800 defines 37.5 or the average over the three items (41.7) has not been checked against the standard | ❌ syntax error | — | p26 |
| Type-level `get_coverage()` | ❌ returns 0 with every bin hit | — | — | p26 |
| FST waveform dump | ✅ `--trace-fst` (needs `liblz4-dev`) | ✅ `vvp -fst` | — | p27 |

Other tools (D-013):

| Capability | Tool | Result | Probe |
|---|---|---|---|
| Coverage data → lcov → HTML; a never-taken branch shows count 0 | Verilator `--coverage`, `verilator_coverage --write-info`, `genhtml` | ✅ | p17 |
| Equivalent refactor proved; a dropped input bit reported | eqy (sby, Yices) | ✅ | p18 |
| Mutation coverage: a checking testbench covers 38 of 40 mutations, a blind one 0 of 40 (seed fixed in the probe; mcy otherwise seeds from the clock) | mcy (Yosys `mutate`, Icarus) | ✅ | p19 |
| Bytes on a simulated `tx` pin decoded by third-party code; a wrong baud rate does not decode | sigrok-cli UART decoder on a VCD through `scripts/vcd_pin.py` | ✅ | p20 |
| C header, Markdown and a reference register block from SystemRDL; overlapping offsets rejected | PeakRDL | ✅ (the generated block needs `-Wno-MULTIDRIVEN` under Verilator; Icarus and Yosys reject it) | p21 |
| Legal file compiles; a double-driven variable is an error with the analysis pass and goes unreported with elaboration alone | slang | ✅ | p22 |
| Project rule file passes a conforming file and reports a planted violation of each of its 14 rules; with an empty rule file the same violations pass | svlint | ✅ | p23 |

### 2.2 Rules

**RTL (must pass all three tools):**

1. **No `import`, no `return`.** Use package-qualified names
   (`uart_pkg::baud_t`, `uart_pkg::parity(d)`) and Verilog-2001 function-name
   assignment (`parity = ^d;`). (p03)
2. **No SystemVerilog interfaces in synthesizable RTL** (D-011). Every port in
   `rtl/` is a plain signal or a packed struct from the package, written with
   a package-qualified name (rule 1). Assign struct members one by one, never
   with a named assignment pattern. Interfaces and virtual interfaces belong
   in `tb/`, where class-based benches are Verilator-only (rule 6). Icarus
   rejects an interface port anywhere in the hierarchy, not only at the top.
   (p02, p16; `.svlint.toml` enforces it, p23)
3. **Parameter checks:** `if (bad) begin : g_chk $error("single literal"); end`.
   No format arguments. (p08)
4. **No blanket `-Wno-fatal`.** Silence specific lint codes locally. If a flow
   must make warnings non-fatal, add `-Werror-USERERROR` so elaboration
   `$error` stays fatal. (BUG-002)

**Testbenches:**

5. **Drive with NBA at the active edge (or blocking at the opposite edge);
   check at the opposite edge.** (p04, BUG-001)
6. **Verilator is the primary simulator.** Class-based, constrained-random
   and concurrent-SVA testbenches are Verilator-only. Icarus runs only plain
   directed tests as a second opinion. (p05, p06, p09)
7. **TBs must be Verilator lint-clean:** explicit width casts, and no
   initializers on variables declared in procedural blocks (`IMPLICITSTATIC`):
   such a variable is static, so its initializer runs once, not on every
   pass of a loop. (p24)
8. **Self-checking verdict = exit code AND `PASS` marker AND no `FAIL`
   marker.** For Icarus, also grep the log for `ERROR`, because a failing
   assertion does not change its exit code. (p07) For UVM, also require
   `UVM_ERROR : 0` and `UVM_FATAL : 0` in the report, because a `uvm_error`
   does not change the exit code either. (p15)

**Assertions / formal:**

9. **Concurrent SVA is sim-only (Verilator).** Formal properties are
   immediate assertions in clocked `always` blocks, using `$past` and an
   `f_past_valid` guard on every check that reads history or state that
   isn't reset yet. (p10, p11, p13)
10. **Formal checkers are instantiated explicitly under `` `ifdef FORMAL``,
    never via `bind`.** Yosys drops `bind` without a warning. (p12)
11. **Input requirements use `` `ASSUME``**: assume in formal, assert in sim.
    Every assumption must be matched by an assertion where the input is
    driven. (p13)
12. **Every property set has a must-fail twin** (or a cover) proving it is
    not vacuous. (p07, p09, p10, p12)
13. **Report BMC results as "no failure up to depth N".** Only a passing
    `mode prove` counts as "proved". (p14)

**Tools added by D-012 and D-013 (rule 19: D-016):**

14. **UVM runs on Verilator** with the uvm-verilator kit and its DPI file
    (`--vpi`, `$UVM_HOME/src/dpi/uvm_dpi.cc`). Lint is switched off for the
    library path only, through a `.vlt` configuration file; never with a
    blanket `-Wno-lint` or `-Wno-fatal`. (p15)
15. **Coverage is published as an lcov HTML report** built from Verilator's
    `coverage.dat`. (p17)
16. **A second front end and a style linter read the RTL:** slang through
    `scripts/slang_check.py` (it must run slang's analysis pass, or a
    double-driven variable goes unreported) and svlint with `.svlint.toml`
    (svlint checks only the rules its rule file lists: with an empty rule
    file it reports nothing, and with no rule file at all version 0.9.5
    switches every rule on, so the file is always passed with `-c`).
    (p22, p23)
17. **The PeakRDL reference register block** is generated with
    `--cpuif apb3-flat --default-reset arst_n --err-if-bad-addr` and is
    simulation-only, on Verilator: Icarus and Yosys both reject it, and
    under Verilator it needs `-Wno-MULTIDRIVEN` for that block alone. So it
    cannot be compared with the hand-written block by eqy; the comparison
    is made in simulation. (p21, D-007)
18. **Every new check is shown failing once** before it is relied on: each
    probe from p15 to p26 keeps a file or a run that must fail, except
    p17 (its evidence is a branch that must show count 0), p25 and p27
    (ports of the original suite: a feature works or does not). A tool
    that reports nothing may simply not be looking. (p15 to p26)
19. **PROCASSINIT stays on for `rtl/`** (D-016). `-Wall` on Verilator 5.050
    enables it (a declaration initializer on a variable that a process also
    assigns); in RTL, reset sets state, not an initializer (D-001). It is
    waived for testbench files, and locally for the `f_past_valid`
    declaration of rule 9, where the initializer is the idiom. (p24)

**Quality rules (D-015):**

20. **A lint waiver sits next to the line it covers, with its reason.** No
    file-wide or command-line waiver for RTL. The number of waivers is
    printed in the lint report and may only go down, unless an increase is
    approved and recorded. (BUG-002: a blanket waiver hid a real error)
21. **The regression reports two mutation scores:** the named mutants in
    `tb/mutants/` (known bugs, planted under a define; the regression must
    fail on each) and mcy's random mutations. (p19)
22. **Every report is stamped** with the command, the tool versions and the
    commit, and counts as evidence only on the pinned versions of §1.1.
    (p24: PROCASSINIT is reported only under `-Wall`. Ubuntu 24.04's
    Verilator 5.020 does not report it at all; that was seen by hand on
    2026-11-15 and is not pinned by a probe, since one version is installed)
23. **Nothing is claimed without a report:** a sentence in the README, the
    datasheet or the changelog that holds a number or says verified, proved,
    covered, passes or meets timing links to a file in `build/reports/` or
    to a row of the traceability matrix. `make check-docs` already checks the
    README's probe numbers. (p08, BUG-002: a check can pass for the wrong reason)

### 2.3 Findings from the original line (ported on 2026-11-15, milestone M0b)

Measured on the Mac host with the original probe suite, kept in `tb/probes/mac_suite/`
(`make probe-mac`; cloud-host status in its README). All four are now also in the main suite:
mailboxes in p25, covergroups in p26, `--coverage` in p17 and the FST dump in p27, with the same
results. The table below keeps the Mac suite's own probe numbers.

| Construct | Needed for | Verilator 5.050 | Icarus 13.0 | Yosys/sby | Fallback if unsupported |
|---|---|---|---|---|---|
| Classes, queues, mailboxes | Modular TB (transaction/driver/monitor/scoreboard) | **PASS** incl. inheritance + virtual dispatch [p01] | **FAIL** — syntax error at `mailbox #(txn)` [p01] | n/a | Struct-based transactions + tasks (only if the TB must run on Icarus) |
| `covergroup` / `coverpoint` / `cross` | Functional coverage | **PASS with caveats** — bins + cross counted; `get_inst_coverage()` returns 37.5, then 100. Type-level `get_coverage()` returns 0 even when bins are hit; `cg.cp.get_coverage()` does not compile [p03] | **FAIL** — syntax error [p03] | n/a | Query with `get_inst_coverage()` only; per-coverpoint numbers from `coverage.dat` (`--coverage`) |
| `--coverage` (line/toggle) | Code coverage | **PASS** — `coverage.dat` written; `verilator_coverage --annotate` shows the never-taken branch at count 0 [p07] | n/a | n/a | — |
| FST waveform dump | Debug in Surfer | **PASS** with `--trace-fst` **plus** `-CFLAGS -I/opt/homebrew/include -LDFLAGS -L/opt/homebrew/lib` (the FST writer needs `lz4.h`; Apple clang does not search Homebrew paths) [p08] | **PASS** with `vvp -fst` (corrects the earlier "VCD only") [p08] | n/a | VCD |

### 2.4 Toolchain gotchas (original line)

- Verilator treats any `//` comment whose first word is `verilator` as a pragma
  (`%Error-BADVLTPRAGMA`). Don't start a comment with the tool name. This holds in `.vlt`
  configuration files too, and in any letter case (seen again on the cloud host, 2026-11-15).
- `sby` (this install): a line prefixed with several task names (`a b: …`) was not applied
  (the job reported "Missing mode"); one task name per prefix works.
- Without an SMT solver, `abc pdr` can still *prove* properties, but every failing property
  ends as an sby ERROR without a counterexample trace (observed before Yices was installed).

---

## 3. RTL coding conventions

**Files**
- One module per file; file name = module name; `.sv` extension.
- `` `default_nettype none `` at the top of every RTL file, `` `default_nettype wire `` at the end.
- Short header comment: purpose, clock/reset domain, key parameters.
- Every file starts with `SPDX-License-Identifier: Apache-2.0` and an `SPDX-FileCopyrightText`
  line (D-009, extended to every file on 2026-11-15). A file that cannot carry a comment is
  listed in `REUSE.toml`. `make license` runs `reuse lint`.
- Synthesizable RTL lives only in `rtl/`. No `#` delays, no `initial` blocks (exception:
  FPGA memory initialization, documented), no `$display` in synthesizable paths.

**Naming**
- `clk` / `clk_<domain>`; active-low signals end in `_n` (`rst_n`).
- Registers: `<name>_q`; next-state combinational value: `<name>_d`.
- Parameters `UPPER_CASE`; derived constants as `localparam`.
- Port direction is visible from the port list (ANSI style); no `i_`/`o_` prefixes required.
- Interfaces/buses use a consistent protocol prefix (`psel`, `penable`, … for APB).

**Logic**
- `always_ff` for sequential logic with nonblocking assignments only.
- `always_comb` for combinational logic with blocking assignments; assign defaults at the top
  of every `always_comb` to prevent latches.
- Explicit widths on all literals where width matters; no implicit truncation/extension.
- Derived widths via `$clog2`, guarded for edge cases (e.g. `DEPTH = 1`).

**FSMs**
- `typedef enum logic [N-1:0] { ... } state_t;` with explicit encoding where it matters.
- Separate state register (`always_ff`) and next-state/output logic (`always_comb`).
- Every `case` has a `default` that returns to a safe state; document the illegal-state policy.
- Use `unique case` only when mutual exclusivity is guaranteed and understood.

**Parameters**
- Validate legal parameter ranges at elaboration time (generate-block `$error` or equivalent
  confirmed by probe). Parameterize only what is genuinely reusable.

---

## 4. Reset convention — APPROVED (D-001, 2026-10-10)

- Single active-low reset input `rst_n`.
- Asynchronous assertion, synchronous deassertion via a 2-flop reset synchronizer per clock domain.
- Reset only control state (FSM state, valid flags, pointers, counters); datapath registers
  that are always written before being read may be left unreset — document each such choice.
- Outputs are protocol-legal (idle) while in reset and on the first cycle after release.

This applies to every project unless overridden by a later entry in `docs/decisions.md`.

---

## 5. Assertions and formal style

Goal: a small set of high-quality properties that never clash between simulation and formal.

- **Formal properties** live in the RTL under `` `ifdef FORMAL `` or in `formal/properties/`,
  written in the subset that open-source Yosys accepts: immediate `assert`/`assume`/`cover`
  inside clocked `always` blocks, using `$past` with an `f_past_valid` guard. Treat
  concurrent SVA as unsupported in formal unless a probe proves otherwise.
- **Environment constraints** use an `ASSUME` macro that expands to `assume` under `FORMAL`
  and to `assert` in simulation. This way the same property is a constraint when proving the
  DUT and a check on the testbench when simulating — they cannot contradict each other.
- **Simulation-only temporal checks** (richer SVA) live in `assertions/`, attached via `bind`
  or a checker instance, and only if the probe in §2 passes.
- Each property has an ID tying it to a requirement (`// REQ-FIFO-003`).
- Every formal run records: depth, mode (`bmc` / `prove`), engine, solver, result, and the
  counterexample trace path if it fails.

---

## 6. FPGA flow (Basys 3 / Artix-7) — APPROVED (D-002, 2026-10-10)

Vivado does not run natively on macOS, so the flow is tiered:

| Tier | Flow | Runs on | When | Evidence produced | Status of numbers |
|---|---|---|---|---|---|
| 1. Resources | Yosys `synth_xilinx` | Mac + CI | Every commit, from v0.1 | `build/reports/synth.txt` (LUT/FF/BRAM/LUTRAM/DSP, inferred-memory check) | Pre-P&R estimate |
| 2. Bring-up | openXC7 (Yosys → nextpnr-xilinx → Project X-Ray) + openFPGALoader (`-b basys3`) | Mac (Linux container as fallback) | v1.0 bring-up, optionally earlier | Bitstream, programmed board, `sigrok-cli` UART decode in `build/reports/bringup/` | Timing indicative only |
| 3. Sign-off reports | Vivado (free edition, XC7A35T) | x86 Linux/Windows machine (lab PC or cloud VM) | Once per release, at v1.0 | `report_utilization`, `report_timing_summary` against the XDC clock constraint, saved to `build/reports/vivado/` | Quotable implementation results |

Rules:
- RTL in `rtl/` is vendor-neutral: no Xilinx primitives or vendor attributes. Board-specific
  logic lives in `rtl/board/` (board top, clock/reset input buffering, LED/switch glue).
- One constraint file, `constraints/basys3.xdc`, holds pin LOC/IOSTANDARD and the 100 MHz
  `create_clock`. Vivado uses all of it; the open flow uses the pin constraints. If a flow
  needs a different format, generate it from the XDC with a script rather than maintaining
  two files.
- Every reported timing or resource number names the tier and tool version it came from.
  Tier 1 and Tier 2 numbers are never presented as Vivado results.
- Tier 2 setup on macOS is community-supported; if it fails, record the limitation in
  `project_status.md` and move bring-up to the Tier 3 machine.
- Vivado runs are scripted in Tcl (`scripts/vivado_build.tcl`, non-project mode) so they
  are reproducible on any x86 machine.

**Bring-up evidence:** capture the UART TX pin with `sigrok-cli` and its UART decoder, and
save the decoded log under `build/reports/bringup/`. That is hard evidence for the README.

---

## 7. Make targets

| Target | Does | Status reporting | Implemented |
|---|---|---|---|
| `make toolchain` | Builds the pinned tools into `/opt/eda` (cloud host, D-004) | exits nonzero on build failure | yes |
| `make probe` | Runs all capability probes | pass/fail per probe | yes |
| `make probe-mac` | Runs the original Mac M0 suite in `tb/probes/mac_suite/` | pass/fail per probe vs its own baseline | yes |
| `make probe-accept` | Copies the latest probe results over `tb/probes/expected.txt` (after review) | — | yes |
| `make sim TEST=<name> SEED=<n>` | One test, one seed, waveform dump | exits nonzero on failure | planned |
| `make regression` | All tests × seeds × configs; summary table | `build/reports/regression.txt` | planned |
| `make lint` | `verilator --lint-only -Wall` on all RTL | warnings listed, not hidden | planned |
| `make formal` | All `.sby` jobs | per-job pass/fail + depth | planned |
| `make synth` | Tier 1: Yosys `synth_xilinx` resource report | `build/reports/synth.txt` | planned |
| `make fpga` | Tier 2: openXC7 place-and-route + bitstream | `build/fpga/*.bit`, nextpnr log | planned |
| `make prog` | Tier 2: program Basys 3 via openFPGALoader | exits nonzero if the board is not found | planned |
| `make bringup` | Capture + decode UART with `sigrok-cli` | `build/reports/bringup/` | planned |
| `make vivado` | Tier 3: `vivado -mode batch -source scripts/vivado_build.tcl` (x86 machine only) | `build/reports/vivado/` | planned |
| `make license` | `reuse lint`: every file has SPDX license and copyright information | exits nonzero on a missing header | yes |
| `make check-docs` | `scripts/check_docs.py`: decision records complete; every cited decision, bug and probe exists; every rule cites a probe or a bug-log entry; this table matches the Makefile; the quoted baseline matches `expected.txt`. Runs its self-test first | exits nonzero on any disagreement | yes |
| `make clean` | Removes `build/` only | — | yes |

Every random seed used is printed and logged; `make sim TEST=x SEED=n` must reproduce a
failure exactly.

---

## 8. CI

GitHub Actions on every push: `make lint` + `make regression` (Verilator on Ubuntu) and
`make formal` where installable. Pin tool versions in the workflow and note any difference
from the local versions in §1.

Since 2026-11-15 a light workflow (`.github/workflows/checks.yml`, D-015) runs on every push and
pull request: `make check-docs`, `make license`, `shellcheck` and `ruff` on the scripts. It needs
no EDA tool.

From Gate 9 (D-010) a second workflow runs on the pinned image and also runs `make probe`, lint,
the regression and formal; a tool version that differs from §1.1 fails the job, and a planted
failing test must turn it red before it is trusted.
