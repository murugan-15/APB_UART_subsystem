# Conventions — APB UART

Every rule below is backed by a probe in `tb/probes/`; `make probe` re-checks
them against `tb/probes/expected.txt`. If the baseline moves, a rule here
may no longer hold. Re-read the affected section before running `make probe-accept`.

Decided once, reused across projects. A project may override an item only by recording the
reason in `docs/decisions.md`. Items marked **PROPOSED** are awaiting approval.

## 1. Toolchain

### 1.1 Cloud host (verified 2026-10-10)

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
| UVM | — | Not installed. UVM runs on EDA Playground (D-003) |

Probe baseline: **26 PASS / 13 FAIL / 1 UNAVAIL** (40 checks, 15 probes).
Every FAIL below is a confirmed tool limitation (log read, cause known), not
a probe bug.

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
| UVM | UNAVAIL | — | — | p15 |

### 2.2 Rules

**RTL (must pass all three tools):**

1. **No `import`, no `return`.** Use package-qualified names
   (`uart_pkg::baud_t`, `uart_pkg::parity(d)`) and Verilog-2001 function-name
   assignment (`parity = ^d;`). (p03)
2. **Interfaces only inside the RTL hierarchy,** never on a port that Icarus
   TBs must drive. The APB slave's top-level ports are plain signals. (p02)
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
   directed tests as a second opinion.
7. **TBs must be Verilator lint-clean:** explicit width casts, and no
   initializers on variables declared in procedural blocks (`IMPLICITSTATIC`).
8. **Self-checking verdict = exit code AND `PASS` marker AND no `FAIL`
   marker.** For Icarus, also grep the log for `ERROR`, because a failing
   assertion does not change its exit code. (p07)

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

### 2.3 Findings from the original line not yet probed here

Measured on the Mac host with the original probe suite (not in `tb/probes/` on this branch).
Before a milestone relies on one of these, port the probe into `tb/probes/` and re-baseline
(proposed milestone M0b).

| Construct | Needed for | Verilator 5.050 | Icarus 13.0 | Yosys/sby | Fallback if unsupported |
|---|---|---|---|---|---|
| Classes, queues, mailboxes | Modular TB (transaction/driver/monitor/scoreboard) | **PASS** incl. inheritance + virtual dispatch [p01] | **FAIL** — syntax error at `mailbox #(txn)` [p01] | n/a | Struct-based transactions + tasks (only if the TB must run on Icarus) |
| `covergroup` / `coverpoint` / `cross` | Functional coverage | **PASS with caveats** — bins + cross counted; `get_inst_coverage()` correct (37.5 → 100). Type-level `get_coverage()` returns 0 even when bins are hit; `cg.cp.get_coverage()` does not compile [p03] | **FAIL** — syntax error [p03] | n/a | Query with `get_inst_coverage()` only; per-coverpoint numbers from `coverage.dat` (`--coverage`) |
| `--coverage` (line/toggle) | Code coverage | **PASS** — `coverage.dat` written; `verilator_coverage --annotate` shows the never-taken branch at count 0 [p07] | n/a | n/a | — |
| FST waveform dump | Debug in Surfer | **PASS** with `--trace-fst` **plus** `-CFLAGS -I/opt/homebrew/include -LDFLAGS -L/opt/homebrew/lib` (the FST writer needs `lz4.h`; Apple clang does not search Homebrew paths) [p08] | **PASS** with `vvp -fst` (corrects the earlier "VCD only") [p08] | n/a | VCD |

### 2.4 Toolchain gotchas (original line)

- Verilator treats any `//` comment whose first word is `verilator` as a pragma
  (`%Error-BADVLTPRAGMA`). Don't start a comment with the tool name.
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
| `make clean` | Removes `build/` only | — | yes |

Every random seed used is printed and logged; `make sim TEST=x SEED=n` must reproduce a
failure exactly.

---

## 8. CI

GitHub Actions on every push: `make lint` + `make regression` (Verilator on Ubuntu) and
`make formal` where installable. Pin tool versions in the workflow and note any difference
from the local versions in §1.
