# Conventions — APB UART

Every rule below is backed by a probe in `tb/probes/`; `make probe` re-checks
them against `tb/probes/expected.txt`. If the baseline moves, a rule here
may no longer hold. Re-read the affected section before running `make probe-accept`.

## 1. Toolchain (verified 2026-10-10)

Built from source at pinned tags by `scripts/install_toolchain.sh` into
`/opt/eda` (the Makefile puts `/opt/eda/bin` on `PATH`).

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

## 2. Tool support matrix and the rules that follow

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

### Rules

**RTL (must pass all three tools):**

1. **No `import`, no `return`.** Use package-qualified names
   (`uart_pkg::baud_t`, `uart_pkg::parity(d)`) and Verilog-2001 function-name
   assignment (`parity = ^d;`). (p03)
2. **Interfaces only inside the RTL hierarchy,** never on a port that Icarus
   TBs must drive. The APB slave's top-level ports are plain signals. (p02)
3. **Parameter checks:** `if (bad) begin : g_chk $error("single literal"); end`.
   No format arguments. (p08)
4. **No blanket `-Wno-fatal`.** Silence specific lint codes locally. (BUG-002)

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
