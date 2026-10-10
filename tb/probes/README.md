# M0 toolchain capability probes

Run with `make probe`. Each check prints one line `probe check RESULT`;
the set must match `expected.txt` exactly or `make probe` exits 1.

Design rules:

- **Self-checking.** Sims print `PROBE_PASS` only when every check passed,
  and the runner also requires exit code 0. Formal checks read the sby
  `status` file.
- **Dual property / anti-vacuity.** Wherever a tool could silently ignore a
  feature, the probe includes a check that *must fail* and verifies the
  failure happened (exact count in sim, `FAIL` status in formal). A tool
  that drops the feature then shows up as FAIL instead of a false PASS.
- **Race-free TB timing.** Drive with nonblocking assignments at posedge (or
  blocking at negedge), and check at the opposite edge (BUG-001).

| Probe | What it establishes | Checks |
|---|---|---|
| p01_sv_basics | enum/struct/always_ff/always_comb/unique case | verilator, iverilog, yosys-synth |
| p02_interfaces | parameterized interface + modports | verilator, iverilog, yosys-synth |
| p03_packages_generate | package import in header, `$clog2`, packed 2-D ports, generate-for | verilator, iverilog, yosys-synth |
| p04_nba_ordering | race-free drive/sample convention gives identical results | verilator, iverilog |
| p05_classes | virtual class, pure virtual, inheritance, queue of handles | verilator, iverilog |
| p06_randomize | constraints, `inside`, implication, `randomize() with`, value spread | verilator (needs z3), iverilog |
| p07_immediate_assert | action blocks fire the right number of times; failing default-action assert makes the run exit nonzero | verilator, iverilog, verilator-exit, iverilog-exit |
| p08_elab_error | `$error` in a generate block rejects an illegal parameter, legal one elaborates | verilator, verilator-wnofatal, iverilog, iverilog-fmtargs, yosys |
| p09_concurrent_sva_sim | `\|-> ##N` in sim: good=0 fails, bad=3 fails | verilator, iverilog |
| p10_concurrent_sva_formal | same properties under sby: good PASS, bad FAIL | sby |
| p11_formal_past_guard | guarded `$past` proves / bad variant gives a trace / unguarded fails spuriously | sby-dual-trace, sby-noguard |
| p12_bind | bound checker runs (bad check must fire) | verilator, iverilog, sby |
| p13_assume_macro | `ASSUME` = assume in formal (load-bearing), assert in sim (fires on illegal stimulus) | verilator, verilator-fire, sby |
| p14_bmc_vs_prove | BMC 24 misses a step-30 bug, PDR finds it, PDR proves a true property | sby |
| p15_uvm | UVM compiles and runs | verilator (UNAVAIL without `UVM_HOME`) |

Changing the baseline: inspect `build/probe/diff.txt`, explain the change
in `docs/bug_log.md` or `docs/conventions.md`, then `make probe-accept`.
