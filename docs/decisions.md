# Decision Log

One entry per architectural or convention decision. Newest at the bottom. Never edit a past
entry; supersede it with a new one.

```text
### D-001 — <title>
Date:          YYYY-MM-DD
Phase:         <gate>
Decision:      <what was chosen>
Alternatives:  <what else was considered>
Reason:        <why, with tradeoffs: area / timing / latency / verification / reuse>
Impact:        <files, requirements, tests affected>
Decided by:    <me>
Supersedes:    <D-xxx or none>
```

### D-001 — Reset convention
Date:          2026-10-10
Phase:         Project-wide convention (applies before Phase 0 of every project)
Decision:      Single active-low `rst_n`; asynchronous assertion, synchronous deassertion via a
               2-flop reset synchronizer per clock domain; reset control state only (FSM state,
               valid flags, pointers, counters); datapath registers written-before-read may be
               unreset if documented; outputs protocol-legal (idle) during reset and on the
               first cycle after release.
Alternatives:  Fully synchronous reset; active-high reset; resetting every flop.
Reason:        Async assertion works without a running clock; synchronized deassertion avoids
               recovery/removal violations and flops leaving reset on different cycles; leaving
               written-before-read datapath unreset saves reset routing and area.
Impact:        conventions.md §4; every RTL module; reset tests in every verification plan.
Decided by:    me
Supersedes:    none

### D-002 — FPGA flow
Date:          2026-10-10
Phase:         Project-wide convention
Decision:      Tiered flow. Tier 1: Yosys synth_xilinx resource reports on every commit (Mac +
               CI). Tier 2: openXC7 + openFPGALoader for Basys 3 bitstream and bring-up on the
               Mac, with sigrok-cli capture as evidence. Tier 3: Vivado on an x86 machine once
               per release for utilization and timing reports. RTL stays vendor-neutral; one
               XDC in constraints/.
Alternatives:  Yosys-only (no hardware, no timing); open flow only (no industry-standard
               timing reports); Vivado only (not runnable on this Mac, slows iteration).
Reason:        Fast local feedback on every change, real hardware demo without leaving the Mac,
               and quotable Vivado results, at the cost of occasional access to
               an x86 machine.
Impact:        conventions.md §6–7; Makefile targets synth/fpga/prog/bringup/vivado;
               rtl/board/ separation; the README must name the tier for every reported
               number.
Decided by:    me
Supersedes:    none

### D-003 — Target release cut for the APB UART
Date:          2026-10-10
Phase:         0 — Inspect, preserve, bound (closing)
Decision:      Target v1.0, reached in stages v0.1 → v0.5 → v1.0; each stage is a tagged,
               presentable state with only the claims its evidence supports.
Alternatives:  Stop at v0.1 (directed verification only); stop at v0.5 (constrained-random,
               SVA, coverage, CI — no formal results, FPGA evidence, CDC, or design review).
Reason:        "Production-level IP" requires the v1.0 evidence (formal, FPGA bring-up, design
               review); staging keeps an honest fallback if time runs out. M0 showed the local
               toolchain supports the v1.0 formal and coverage work.
Impact:        All gates in scope through Phase 12. External dependencies: Vivado on x86 for
               Tier 3 reports (D-002), EDA Playground for the UVM port, Basys 3 + sigrok capture
               for bring-up. If one is unavailable, v1.0 ships with that limitation stated.
               CDC content depends on the Phase 3 async-FIFO decision.
Decided by:    me
Supersedes:    none


### D-004 — Toolchain built from source on the cloud host
Date:          2026-10-10
Phase:         0 — Inspect, preserve, bound (Gate 0 rebuild)
Decision:      On the cloud host the toolchain is built from source at the pinned tags of
               conventions.md §1 by `scripts/install_toolchain.sh` (`make toolchain`) into /opt/eda.
Alternatives:  Ubuntu apt packages; prebuilt OSS CAD Suite tarballs.
Reason:        apt versions are too old (Verilator 5.020, Yosys 0.33); release tarballs are
               blocked by the cloud network proxy. Building from source keeps the same versions
               as the Mac host.
Impact:        scripts/install_toolchain.sh, Makefile `toolchain`; ~40–60 min per fresh container.
Decided by:    me
Supersedes:    none

### D-005 — Repository and project line
Date:          2026-10-10 (line chosen 2026-10-13)
Phase:         0 / 1
Decision:      The project lives in `murugan-15/APB_UART_subsystem`, default branch `main`.
               `main` (the rebuilt Gate 0 line) is the project line; useful content from the
               original line (the original-line branch) is merged into it.
Alternatives:  Keep the original line as the base and port the rebuild onto it; merge both histories.
Reason:        Not stated when decided. (Claude's summary of the tradeoff, for review: `main`
               carries the verified cloud toolchain and probe baseline the remaining phases run on.)
Impact:        project_status.md "Gate 0 history"; conventions.md §1–§2; bug_log.md.
Decided by:    me
Supersedes:    none

### D-006 — Tools and structure check at every gate
Date:          2026-10-23
Phase:         1 (applies to every later gate)
Decision:      Each gate exit includes a tools-and-structure check (project_status.md): the tools
               and repository structure that gate needs are in place, are the right choice, and
               pass a probe before anything relies on them. Results use pass / fail / not run /
               not applicable with evidence.
Alternatives:  Decide tools ad hoc when a phase starts; review once at the readiness gate.
Reason:        Production IP needs more than RTL (register description, lint, regression, CI,
               packaging, docs). Checking per gate adds each piece when it is first needed and
               keeps the public repository reproducible by anyone, including through CI.
Impact:        project_status.md "Tools and structure check"; new directories are created only
               when their gate needs them.
Decided by:    me
Supersedes:    none

### D-007 — Register description in SystemRDL; register RTL written by hand
Date:          2026-10-23
Phase:         1 (implemented at Gate 3)
Decision:      The register map is described once in SystemRDL (`rdl/`). PeakRDL generates the
               C header and the register documentation from it. The APB register block RTL is
               written by hand. At v0.5, PeakRDL's generated register block is compared with the
               hand-written one in simulation.
Alternatives:  Hand-written docs and header (they drift from the RTL); generate the RTL too
               (skips the decode / read-mux / W1C logic this project exists to practise, and the
               generated SystemVerilog may not pass Yosys 0.69 without a probe).
Reason:        One source of truth for software-visible facts, an industry-standard format,
               installable with pip in the cloud host and in CI.
Impact:        `rdl/`, Makefile target for generation, CI check that generated files are current.
Decided by:    me
Supersedes:    none

### D-008 — FPGA demo drives APB with an on-board test sequencer
Date:          2026-10-23
Phase:         1 (implemented at Gate 10; designed at Gate 3)
Decision:      `rtl/board/` contains a small sequencer FSM that acts as the APB master on the
               Basys 3: configure the UART, send a fixed message, then echo received bytes
               (RXDATA -> TXDATA). The same board top runs as a simulation integration test in CI.
               A UART-to-APB debug bridge is rejected (the board's only USB-UART is used by the
               DUT). A soft CPU (e.g. PicoRV32) running the C driver is not decided; revisit after
               v1.0.
Alternatives:  UART-to-APB bridge; soft CPU with firmware.
Reason:        Lowest effort that exercises the full APB -> UART -> pin path on hardware, is
               deterministic, and is testable in CI without a board.
Impact:        `rtl/board/`, an integration test, bring-up evidence in `build/reports/bringup/`.
Decided by:    me
Supersedes:    none

### D-009 — License: Apache-2.0
Date:          2026-10-23
Phase:         1
Decision:      The repository is licensed under Apache-2.0 (`LICENSE`); new source files carry an
               `SPDX-License-Identifier: Apache-2.0` line.
Alternatives:  Solderpad Hardware License 2.1; CERN-OHL-S/W; no license.
Reason:        Widely recognised, permissive, includes a patent grant, used by large open
               hardware projects; no license would mean all rights reserved.
Impact:        `LICENSE`; SPDX headers from the first RTL file on.
Decided by:    me
Supersedes:    none

### D-010 — CI anyone can run, on a pinned toolchain image
Date:          2026-10-23
Phase:         1 (implemented at Gate 9)
Decision:      A workflow builds a container image from `scripts/install_toolchain.sh` (the same
               pinned versions as conventions §1) and publishes it to GitHub Container Registry.
               CI runs lint, probes, regression and formal on every push using that image, with a
               status badge in the README. A devcontainer lets anyone open the repository in
               GitHub Codespaces and run `make ci`. Forks run the same workflows without secrets.
Alternatives:  Build tools from source in every CI run (40-60 min); a prebuilt third-party
               bundle (versions differ from the pinned ones).
Reason:        Reviewers can see, rerun (in a fork or Codespace) and reproduce every check with
               identical tool versions.
Impact:        `.github/workflows/`, `.devcontainer/`, container image name in conventions §8.
Decided by:    me
Supersedes:    none

### D-011 — No SystemVerilog interfaces in synthesizable RTL
Date:          2026-11-15
Phase:         1 (applies from the first RTL file, Gate 5)
Decision:      Conventions rule 2 is rewritten. Every port in `rtl/` is a plain signal or a
               packed struct typedef'd in the package; struct members are assigned one by one.
               Interfaces and virtual interfaces are used only in `tb/`.
Alternatives:  Keep the old rule (interfaces allowed inside the hierarchy, plain ports at the
               top); allow interfaces and drop Icarus as the second simulator.
Reason:        The old rule contradicted its own probe: p02 uses an interface only inside the
               hierarchy, and Icarus 13.0 still rejects it at the submodule ports, so any
               internal interface breaks "RTL must pass all three tools". Plain ports are also
               what an integrator, a synthesis flow, an FPGA top and PeakRDL's flat APB option
               connect to. Probe p16 shows the replacement works on all three tools: a packed
               struct on a port passes Verilator, Icarus and Yosys; a named assignment pattern
               does not pass Icarus or Yosys.
Impact:        `docs/conventions.md` §2.1 and rule 2; probe p16; `.svlint.toml` forbids
               interfaces, modports and interface ports in RTL.
Decided by:    me
Supersedes:    none (corrects conventions rule 2; no earlier decision record)

### D-012 — UVM runs on Verilator, from this repository
Date:          2026-11-15
Phase:         1 (used at Gate 7 and for the v1.0 cut)
Decision:      The UVM testbench of the v1.0 cut is built and run with the pinned Verilator and
               the CHIPS Alliance `uvm-verilator` kit (tag `uvm-2020-3.2`, Apache-2.0), installed
               by `scripts/install_toolchain.sh`. A UVM run's verdict includes the report
               counts (`UVM_ERROR : 0`, `UVM_FATAL : 0`). EDA Playground becomes optional.
Alternatives:  Keep UVM on EDA Playground only (D-003's impact line); drop UVM.
Reason:        A result on EDA Playground cannot be rerun from this repository or by CI, so it
               could not meet the evidence rule. Probe p15 shows UVM 2020 with its DPI layer
               compiles and runs on Verilator 5.050 with 0 warnings and 0 errors, in about two
               minutes of build time. The same probe pins one trap: a `uvm_error` leaves the
               exit code at 0.
Impact:        `scripts/install_toolchain.sh`; probe p15 (three checks); conventions rules 8 and
               14; the "EDA Playground for the UVM port" dependency in D-003 no longer blocks
               v1.0. Accellera's own `uvm-core` 2020.3.1 is not used: its DPI layer has no
               Verilator backend.
Decided by:    me
Supersedes:    D-003, only its dependency on EDA Playground for the UVM port

### D-013 — Pinned toolchain extended for the production-level checks
Date:          2026-11-15
Phase:         1 (each tool is first used at the gate named below)
Decision:      The pinned toolchain of D-004 gains: mcy and eqy 0.69 (mutation coverage and
               equivalence, Gates 7 and 8), svlint 0.9.5 with `.svlint.toml` and slang through
               pyslang 12.1.0 (lint, Gate 5), PeakRDL 1.5.0 (register documentation and C
               header, Gate 3), lcov 2.0 (coverage report, Gate 7), sigrok-cli 0.7.2 as an
               independent UART line monitor (Gates 7 and 10), reuse 6.3.0 (license headers),
               FuseSoC 2.4.7 (packaging, Gate 11) and WaveDrom 2.0.3 (diagrams). Python tools
               are pinned in `requirements-tools.txt`; the install script skips what is already
               at its pinned version and exits nonzero if a step fails.
Alternatives:  Add each tool when its gate starts (D-006's default); use a prebuilt bundle
               (versions differ from the pinned ones, and release downloads are blocked on the
               cloud host).
Reason:        The standard needs checks the six original tools cannot make: a second opinion on
               the SystemVerilog, style rules, a readable coverage report, proof that the tests
               find planted bugs, equivalence of two versions of a block, generated register
               documents, and a line monitor that shares nothing with the RTL. All are free,
               run on the cloud host and in a CI image, and each has a probe with a run that
               must fail (p17 to p23), so `make probe` shows on any host that they really check.
Impact:        `scripts/install_toolchain.sh`, `requirements-tools.txt`, `.svlint.toml`,
               `scripts/slang_check.py`, `scripts/vcd_pin.py`, probes p17 to p23, conventions
               §1.1, §2.1 and rules 14 to 18. Probe baseline re-accepted: 40 PASS / 17 FAIL /
               0 UNAVAIL over 57 checks. Not covered by any free tool, and stated as limits:
               CDC sign-off (a written review plus a structural script) and Vivado timing
               (Tier 3 of D-002, reports committed).
Decided by:    me
Supersedes:    none (extends D-004)

### D-014 — License and copyright information on every file
Date:          2026-11-15
Phase:         1
Decision:      Every file carries SPDX license and copyright information: a header in each code
               file, and a `REUSE.toml` entry for documents, probe baselines, placeholder files
               and the original Mac probe suite. `make license` runs `reuse lint`; CI runs it
               from Gate 9.
Alternatives:  Headers from the first RTL file on only (D-009's impact line).
Reason:        59 of the 67 tracked files had no license information, and a reviewer or a tool
               reading one file cannot see the repository's `LICENSE`. The REUSE check makes the
               rule mechanical.
Impact:        `REUSE.toml`, `LICENSES/Apache-2.0.txt`, headers in 56 code files, Makefile target,
               conventions §3 and §7.
Decided by:    me
Supersedes:    D-009, only its "from the first RTL file on" scope

### D-015 — Quality rules for every artifact; light CI now
Date:          2026-11-15
Phase:         1 (applies to every later gate)
Decision:      Seven rules hold for every artifact from now on: every number is computed by a
               script and names its basis; a check counts only after it has been seen to fail on
               a planted error; every new or changed artifact is read by a second, independent
               reviewer before approval; every bug leaves a check and a planted error that proves
               the check; a decision triggers a sweep of everything that assumed otherwise;
               nothing a check depends on lives outside the repository; a result is evidence only
               on the pinned tool versions. Each gate exit also needs an acceptance sample of
               its documents read by the second reader with no error found (150 items; 300 for
               release documents). A light CI workflow runs the document, license and script
               checks on every push now, ahead of the Gate 9 image.
Alternatives:  Keep adding one check per error after it is found; rely on the author rereading;
               wait for Gate 9 before anything runs automatically; a sample of 60 items.
Reason:        Checks written after each error catch that error again, not the next one of its
               kind, and several author-only reviews each found new errors. Until something runs
               on every push, a check protects the project only when someone remembers to run
               it. With no error found, a sample of 150 bounds the remaining error rate below
               2.0 % and one of 300 below 1.0 %, at 95 % confidence; 60 would bound it only
               below 4.9 %.
Impact:        `docs/conventions.md` rules 18 and 20 to 23 and §8; `.github/workflows/checks.yml`;
               `scripts/check_docs.py`. The controls for later gates (requirement checks,
               generated traceability, named mutants, report stamps, the claims check) are built
               at their gates.
Decided by:    me
Supersedes:    none (D-010 still decides the Gate 9 image)

### D-016 — PROCASSINIT on for RTL, waived for testbenches
Date:          2026-11-15
Phase:         1 (applies from Gate 5)
Decision:      Conventions rule 19 is adopted: Verilator's PROCASSINIT warning stays on for
               `rtl/`; testbench files waive it, and so does the `f_past_valid` declaration.
Alternatives:  Waive it everywhere; fix every testbench declaration instead of waiving.
Reason:        In RTL a declaration initializer hides state that reset should set (D-001). In a
               testbench, and for `f_past_valid` in formal, the initializer is the normal idiom
               and simulates correctly. Probe p24 shows the warning exists only under `-Wall`.
Impact:        `docs/conventions.md` rule 19; `make lint` (Gate 5).
Decided by:    me
Supersedes:    none
