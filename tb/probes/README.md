# Toolchain capability probes

Suite M0 (p01 to p15, Gate 0) and the tool probes of D-011 to D-013 (p15 extended, p16 to p24), and milestone M0b (p25 to p27, ported from `mac_suite/`).

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
| p15_uvm | UVM 2020 with its DPI layer compiles and runs on Verilator (uvm-verilator kit); a planted `uvm_error` shows in the report counts but not in the exit code | verilator, verilator-error-exit (known FAIL), verilator-error-report (UNAVAIL without the kit) |
| p16_struct_port | packed struct from a package on a module port; named assignment patterns are not portable | verilator, iverilog, yosys-synth, verilator-twin, verilator-named-pattern, iverilog-named-pattern, yosys-named-pattern |
| p17_coverage_report | Verilator coverage → lcov → HTML; a never-taken branch shows count 0 | verilator-lcov |
| p18_equivalence | eqy proves an equivalent refactor and reports a planted difference | eqy |
| p19_mutation | mcy: a checking testbench covers 38 of 40 mutations (seed fixed), a blind one covers none | mcy |
| p20_line_monitor | sigrok-cli's UART decoder reads the bytes on a simulated `tx` pin; a wrong baud rate does not decode | sigrok |
| p21_register_gen | PeakRDL: C header, Markdown and a reference register block from SystemRDL; overlapping offsets are rejected; Icarus and Yosys must reject the generated block | peakrdl |
| p22_second_frontend | slang compiles a legal file and rejects a double-driven variable (with elaboration alone it does not); Icarus accepts the same file, Verilator rejects it | slang, iverilog (known FAIL), verilator |
| p23_style_lint | svlint with `.svlint.toml` passes a conforming file and reports a planted violation of every rule it switches on; an empty rule file reports none | svlint |
| p24_tb_lint | the lint warnings the testbench rules rely on fire: a static initializer in a loop, an implicit width extension, and (under `-Wall` only) a declaration initializer on a procedurally assigned variable | verilator-implicitstatic, verilator-width, verilator-procassinit |
| p25_mailbox | classes, queues and a mailbox between a producer and a consumer | verilator, iverilog (known FAIL) |
| p26_covergroup | bins and a cross are counted: 37.5 after one sample, then 100 from `get_inst_coverage()`; the type-level query is pinned as a gap | verilator, verilator-type-coverage (known FAIL), iverilog (known FAIL) |
| p27_fst_dump | both simulators write a real FST file | verilator, iverilog |

Changing the baseline: inspect `build/probe/diff.txt`, explain the change
in `docs/bug_log.md` or `docs/conventions.md`, then `make probe-accept`.
