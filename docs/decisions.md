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
Reason:        Not stated when decided. (Summary of the tradeoff, written afterwards for review: `main`
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
               generated SystemVerilog is rejected by Yosys 0.69 and Icarus, probe p21).
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
               compiles and runs on Verilator 5.050 with 0 warnings and 0 errors. The library
               build takes over a minute, so the three p15 checks share one build. The same probe pins one trap: a `uvm_error` leaves the
               exit code at 0.
Impact:        `scripts/install_toolchain.sh`; probe p15 (three checks); conventions rules 8 and
               14; the "EDA Playground for the UVM port" dependency in D-003 no longer blocks
               v1.0. Accellera's own `uvm-core` is not used: its DPI layer has backends for
               VCS, Questa and Xcelium only (`src/dpi/uvm_hdl.c` line 33 of
               github.com/accellera-official/uvm-core at commit 78c0654, read 2026-11-15).
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
               run on the cloud host and in a CI image. mcy, eqy, slang, svlint, PeakRDL and
               sigrok-cli each have a probe with a run that must fail (p18 to p23); lcov has p17,
               whose evidence is a branch that must show count 0. reuse is checked by
               `make license`. FuseSoC and WaveDrom are installed but have no probe yet: each
               gets one before its first use (conventions §1.1).
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
               and the original Mac probe suite. `make license` runs `reuse lint`; the light CI workflow
               runs it on every push (D-015).
Alternatives:  Headers from the first RTL file on only (D-009's impact line).
Reason:        No tracked file carried an SPDX header: at commit 5892751 `reuse lint` reported
               license information on 0 of the 59 files it examines (67 were tracked; only
               `LICENSE` held the license text). A reviewer or a tool
               reading one file cannot see the repository's `LICENSE`. The REUSE check makes the
               rule mechanical.
Impact:        `REUSE.toml`, `LICENSES/Apache-2.0.txt`, headers in 56 code files, Makefile target,
               conventions §3 and §7.
Decided by:    me
Supersedes:    D-009, only its "from the first RTL file on" scope

### D-015 — Quality rules for every artifact; light CI now
Date:          2026-11-15
Phase:         1 (applies to every later gate)
Decision:      Eight rules hold for every artifact from now on: every number is computed by a
               script and names its basis; a check counts only after it has been seen to fail on
               a planted error; every new or changed artifact is read by a second, independent
               reviewer before approval; every bug leaves a check and a planted error that proves
               the check; a decision triggers a sweep of everything that assumed otherwise;
               nothing a check depends on lives outside the repository; a result is evidence only
               on the pinned tool versions; evidence is produced first, then the numbers by script,
               then the text. Each gate exit also needs an acceptance sample of
               its documents read by the second reader with no error found (150 items; 300 for
               release documents; an item is one checkable statement, such as a requirement, a
               table row, a numbered rule or a paragraph, and a set with fewer items is read in
               full). A light CI workflow runs the document, license and script
               checks on every push now, ahead of the Gate 9 image.
Alternatives:  Keep adding one check per error after it is found; rely on the author rereading;
               wait for Gate 9 before anything runs automatically; a sample of 60 items.
Reason:        Checks written after each error catch that error again, not the next one of its
               kind, and several author-only reviews each found new errors. Until something runs
               on every push, a check protects the project only when someone remembers to run
               it. With no error found, a sample of 150 bounds the remaining error rate below
               2.0 % and one of 300 below 1.0 %, at 95 % confidence; 60 would bound it only
               below 4.9 %.
Impact:        `docs/conventions.md` rules 20 to 23 and §8 (rule 18, from D-013, already states
               the seen-to-fail rule for probes); `.github/workflows/checks.yml`;
               `scripts/check_docs.py`; ruff and shellcheck in the light CI. The controls for later gates (requirement checks,
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

### D-017 — Receiver start edge: previous sample updated on ticks only
Date:          2026-11-17
Phase:         1 (applies from Gate 3)
Decision:      The receiver's start-bit edge detector compares the synchronized line sampled at
               this 16× tick with the sample taken at the previous tick; the previous-sample flop
               is updated only on ticks.
Alternatives:  A previous-sample flop updated every clock plus an edge flag held until the next
               tick and cleared by it.
Reason:        Both find the edge within one tick (1/16 bit). Updating on ticks needs one flop and
               no flag, and a glitch that comes and goes between two ticks is never seen, so it
               cannot start a false frame check.
Impact:        Guide Set L5 (the open choice becomes this decision), cards 3 and 36, MCQ L5-06.
Decided by:    me
Supersedes:    none

### D-018 — Verification register model from the SystemRDL source (in principle)
Date:          2026-11-17
Phase:         1 (confirmed at Gate 4)
Decision:      The verification register model is generated from the same SystemRDL source as the
               header and docs (D-007), once a generator is chosen and passes a probe with a planted
               failure (conventions rule 18). Gate 4 confirms it or records why not.
Alternatives:  A hand-written register model; no register model (directed register tests only).
Reason:        One source for every software-visible fact is the point of D-007; a hand-written
               model is the one copy that could drift from the RTL unnoticed. No generator for it
               is in the pinned toolchain today, so the choice waits for a probe.
Impact:        Guide Set L7 (PROPOSED becomes this decision); Gate 4 verification plan; a new probe.
Decided by:    me
Supersedes:    none

### D-019 — TX_OVF is a W1C event bit in INT_STATUS with its own enable
Date:          2026-11-17
Phase:         1 (applies from Gate 2; depends on seed open decision 3)
Decision:      If a write to a full TX FIFO is dropped with a flag (seed open decision 3, still
               open), the flag TX_OVF is a write-1-to-clear bit in INT_STATUS with its own INT_EN
               bit, so it can raise irq like the receive error events.
Alternatives:  The same bit with no enable (software polls it); a bit in STATUS, which would stop
               STATUS being read-only.
Reason:        A dropped byte is otherwise invisible to software; STATUS keeps live levels only and
               INT_STATUS keeps latched events, one rule for every bit.
Impact:        Guide 8.1 register map, the Doubts entry on a burst into a full TX FIFO, MCQ D9-03.
Decided by:    me
Supersedes:    none

### D-020 — tx_done means the transmitter is idle
Date:          2026-11-17
Phase:         1 (applies from Gate 2)
Decision:      tx_done is set when the last stop bit has left the shift register and the TX FIFO
               is empty.
Alternatives:  Set when the last byte leaves the FIFO; two separate bits for the two moments.
Reason:        That is the moment software needs: to release an RS-485 driver (E-058), change the
               baud rate or power down. FIFO empty is already covered by the TX level interrupt.
Impact:        The Doubts entry on what tx_done means, and its follow-up; exhibit D27 (it set the bit on the last FIFO
               pop until it was brought to this rule the same day); MCQ items on tx_done.
Decided by:    me
Supersedes:    none

### D-021 — Basis of every requirement, and evidence of every behaviour
Date:          2026-11-25
Phase:         1 (applies from Gate 2)
Decision:      Study material (the revision guide, cards and Doubts notes) gives the overview of the
               blocks and methods and is never the basis of a requirement or a design choice. Every
               REQ-* in docs/spec.md names its basis: a primary reference [Rn §x], an item of the seed
               spec, or an owner decision D-NNN; a design choice proposed in the study material enters
               the spec only through an owner decision. Behaviour is established by evidence on the
               pinned tools (simulation, formal, the board), found by trial and error and recorded with
               its command and result. Each part is enforced at its gate: Gate 2 entry, a check_docs
               rule that refuses a requirement without a basis, shown failing on a planted fixture;
               Gate 2 exit, that rule passing on docs/spec.md, which carries a basis column; Gates 2-3,
               every behaviour claim the spec or the architecture takes is modelled twice, by the
               author and by a second agent that has not seen the author's answer, and is accepted
               only when the two agree; such a claim is still not evidence (the models are not pinned
               tools, D-015) until Gate 5 on, when it becomes a directed test against the RTL; Gate 4,
               the verification plan names those tests and the independent oracle; Gate 7, a
               third-party line decoder (sigrok, probe p20) runs as that oracle.
Alternatives:  Treat the study material as the reference design (its errors would flow into RTL and
               tests, and the same author's text, model and answer key share one understanding);
               adopt every check at once now (holds the project at Gate 1 for checks that only matter
               from Gate 2).
Reason:        Errata E-101 to E-107 were found after the 0-error acceptance sample of 2026-11-16,
               some in material written after it; most are design-level (a wrong condition, a
               receiver limit, an unqualified RAM read mode), the kind RTL, assertions and formal
               would inherit, and one (E-106) is a citation scope error. A requirement that names a
               primary basis and a behaviour shown on a tool cannot inherit them. Phasing the checks by gate keeps the standard without stalling the project.
Impact:        PLANS.md (private) phase criteria; docs/spec.md format at Gate 2; scripts/check_docs.py
               gains a rule at Gate 2; verification plan (Gate 4) lists the independent oracle.
Decided by:    me
Supersedes:    none

### D-022 — Gate 1 closed on measured error rates; the study guide frozen and backed by evidence
Date:          2026-11-27
Phase:         1 (Gate 1 exit; applies from Gate 2)
Decision:      Gate 1 closes with the study guide, cards and Doubts notes frozen at the state of the
               third weighted acceptance sample and its fixes, instead of the 0-error sample of D-015.
               That sample (seed 907428, 150 of the 943 items changed since the 2026-11-16 sample,
               items the sampler marks as hardware-behaviour claims, a keyword match in
               scripts/acceptance_sample.py, weighted 3 to 1) found 1 content error, fixed (E-126).
               Since the sample is weighted, each group is bounded on its own (one-sided 95 %, scripts/
               gate1_bound.py in the private repository, which reads the counts from the sample files):
               hardware-behaviour items 1 of 132 drawn, bound 3.5 % (as sampled, about 5 of 696
               expected wrong, at most 25; after the fix, about 4 of the 564 unread, at most 20);
               other items 0 of 18 drawn, bound 15.3 % (at most 38 of 247). Frozen means no new teaching text: from Gate 2 a
               change to the guide is either an erratum fix (AGENTS.md §5 procedure: erratum row,
               rule, rebuild) or a claim upgraded with evidence, a reference to the test, assertion,
               formal job or board report on the pinned tools that shows it, added when that evidence
               exists. Errors found later are fixed as errata when found. Exception (owner,
               2026-11-27): a new doubt may still get a new Doubts entry, written and read under the
               rules of AGENTS.md §5; a doubt that overlaps a frozen entry gets its own short entry
               that answers only what is new and points to the frozen one (no clubbing into a frozen
               entry, so nothing is explained twice and the frozen text stays as it is).
Alternatives:  Draw further samples until one reads 0 content errors (costly, and partly luck: at the
               measured hardware rate about 37 % of draws of this shape find no error among their 132
               hardware items); a full line-by-line read of
               the guide (the cost of a release, not of a gate); full sampling of hardware claims only,
               each checked against a model before writing.
Reason:        Three weighted samples (1, 3 and 1 content errors) and the reads of each fix show that
               prose about hardware behaviour carries condition and scope errors that no script can
               run; arithmetic is already script-checked. D-021 makes the guide an overview, never the
               basis of a requirement; executable evidence from Gate 5 on is the oracle that prose
               lacks, so the guide converges by being linked to it rather than by more reading. This is
               a relaxation for the Gate 1 study material, the owner's choice: a 0-error draw of this
               weighted shape would have bounded hardware-behaviour items at 2.2 % (D-015's 2.0 % is the
               figure of a uniform sample of 150); the relaxation widens that bound to 3.5 %. The 15.3 %
               for other items is set by the weighting (18 drawn), error or not.
Impact:        PLANS.md (private) Gate 1 exit row and the general exit list; QC-02 (private quality plan);
               the guide's cover states the freeze and its Errata appendix the measured rates; at Gate 2
               entry the private scripts/guide_check.py gains a rule that a guide line changed after
               the freeze is an erratum row or cites evidence, and lets a new Doubts entry pass (the
               owner's exception) (the project repository's check_docs.py cannot read the private
               guide).
Decided by:    me
Supersedes:    D-015 in part: its 0-error acceptance sample, for the Gate 1 study material only. The
               rule stands for every later gate and every other document (spec, plans, reports).

### D-023 — Layout of the requirements specification (docs/spec.md)
Date:          2026-11-27
Phase:         2 (Gate 2 entry)
Decision:      docs/spec.md lists every requirement as a table row with the columns ID
               (REQ-<AREA>-NNN, unique, AREA one of FUNC, IF, TIM, RST, ERR, PAR, NF as PLANS.md
               Phase 2 names them), Requirement (one testable statement with exactly one "shall" and
               no vague word: should, may, TBD, TBC, etc., and/or, as appropriate), Basis (parts
               separated by ";", each exactly one [Rn §x], one D-NNN or one "seed: <item>", never
               the study material, D-021), Stage (v0.1, v0.5 or v1.0, D-003), Verify method (sim,
               assertion, formal, board or review, with at least one of the first four: review never
               stands alone, since every requirement traces to a test, an assertion or a formal
               property) and "How would you verify it?" (the owner's verification intent, never a
               placeholder). It also has the sections Assumptions (A-NN, each with its impact if
               wrong), Non-goals (NG-NN, each with its basis), Unsupported behaviour (UB-NN, each
               with what happens) and Open items (OI-NN: the item, what it affects, who decides and
               by which gate, 2 to 12), the lists PLANS.md Phase 2 asks for; an empty one says
               "None.". `make check-docs` check 8 enforces all of it. The owner adopted this layout
               on 2026-11-27 ("Adopt both", answering the proposal of an ID, Requirement, Basis,
               Stage, Verify method and "How would you verify it?" table with assumption and
               open-item sections); the area list, the non-goal and unsupported-behaviour sections
               and "review never alone" align it with PLANS.md Phase 2 and AGENTS.md §12 (read of
               the step-0 fixes, fixes6b findings 3 to 5).
Alternatives:  ID, Requirement, Basis and Verify only (the first form of check 8: no release
               stage and no method, so the Gate 4 traceability matrix would have to add both); a
               machine-readable source (YAML or a SystemRDL-like file) that generates spec.md, as
               D-007 does for registers (one source for the spec and the Gate 4 matrix, but a second
               format and a generator to maintain before any requirement exists; reconsidered at
               Gate 4 if the matrix cannot be checked against the Markdown table); a free-text
               specification with inline IDs (no column a script can check).
Reason:        The production-level bar (every requirement has an ID, a basis and a trace to a test,
               an assertion or a formal property; open questions name who decides and by which gate)
               is met only when each of those is a column a script can check. The stage ties every
               requirement to the staged release of D-003; the method seeds the Gate 4 plan.
Impact:        scripts/check_docs.py check 8 (self-test 43 of 43); conventions section 7 (make
               check-docs); PLANS.md (private) Gate 2 exit row; project_status.md Next step; the
               private session_state.md handoff; the Gate 2 deliverable.
Decided by:    me
Supersedes:    none

### D-024 — One executable model and a second reader for behaviour claims at Gates 2-3; the 15-day plan
Date:          2026-11-27
Phase:         2 (Gate 2 entry; applies to Gates 2-3)
Decision:      Every behaviour claim the spec or the architecture takes is backed by one executable
               model in scripts/ (a cycle model whose assertions state the claim and which is shown
               failing on a planted bug), read by a second reader with no authoring context; it is
               accepted when the reader finds no ERROR. It stays a claim, not evidence, until its
               Gate 5 directed test passes against the RTL (D-021 unchanged on that point). The owner
               also set the project's plan: all three releases (D-003) complete within 15 days, by
               2026-12-12, with every task that does not serve the standard cut.
Alternatives:  Two independent models per claim, the second written without the first author's
               answer (D-021 as written: two models' work for each claim, and both remain claims until
               Gate 5); no model before the RTL (claims reach the RTL unchecked).
Reason:        The Gate 5 directed test against the RTL is the oracle; a second model before it adds
               less than its cost under a 15-day plan, while one executable model read by a second
               reader still catches the errors a model catches (E-104, E-134 were found this way).
Impact:        PLANS.md (private) row "2-3"; the Gate 3 receiver model; the private session state.
Decided by:    me
Supersedes:    D-021 in part: its double modelling at Gates 2-3 only; every other part of D-021 stands.

### D-025 — A write to TXDATA when the TX FIFO is full is dropped and flagged (seed decision 3)
Date:          2026-11-27
Phase:         2
Decision:      A TXDATA write that finds the TX FIFO full completes with no wait state and no
               PSLVERR, does not change the FIFO, and sets TX_OVF (D-019).
Alternatives:  Stall with PREADY low until a slot frees (holds the APB for up to one character,
               about 87 us at 115200 8N1 and 1.26 ms at 9600 8E2 at PCLK 50 MHz by
               scripts/apb_stall_numbers.py, and
               deadlocks with TX disabled); PSLVERR with the byte dropped (flow control becomes bus
               faults, R4 §3.4.3); drop silently with no record, as R21 §18.4 does.
Reason:        One defined outcome per case, checkable by a test and an assertion; the system bus is
               never held by the line rate; the loss is visible to software through TX_OVF.
Impact:        D-019 now applies unconditionally; docs/spec.md REQ-IF and REQ-ERR rows; datasheet
               driver contract (check the TX-full status bit before writing).
Decided by:    me
Supersedes:    none

### D-026 — A read of RXDATA when the RX FIFO is empty returns 0 and does not pop (seed decision 4)
Date:          2026-11-27
Phase:         2
Decision:      A RXDATA read that finds the RX FIFO empty completes with no wait state and no
               PSLVERR, returns 0 on PRDATA, and does not move the read pointer (pop is the RXDATA
               read gated by not empty).
Alternatives:  Return the last value (leaks the storage read mode); PSLVERR (R4 §3.4: the
               requester may still use PRDATA, and a normal poll race becomes a bus fault); a valid
               flag in the RXDATA word, as R21 §18.5 does (self-describing read, one more bit and a
               change to the seed map).
Reason:        Defined value and no state change, both testable; the driver contract (read the RX
               empty status bit or use the RX interrupt before RXDATA) is stated in the datasheet,
               since a returned 0 alone does not say whether a byte was received.
Impact:        docs/spec.md REQ-IF and REQ-ERR rows; datasheet driver contract; Gate 3 read path.
Decided by:    me
Supersedes:    none

### D-027 — An unmapped access, or a write to a read-only register, gets PSLVERR with no side effect (seed decision 7)
Date:          2026-11-27
Phase:         2
Decision:      The whole address window of the block is fully decoded. A read or write of an offset
               with no register, and a write to a read-only register, completes with PSLVERR, PRDATA
               0 on a read, and changes no register, FIFO or flag. The window width is a parameter
               fixed at Gate 3.
Alternatives:  Read as zero and write ignored with no error (aliasing and driver bugs stay hidden);
               leave such accesses unpredictable, as R3 §3.1 does (no test can check it); error only
               within the decoded address bits and alias beyond them, as R22 describes (a stray
               access beyond the bits can pop RXDATA).
Reason:        Every offset in the window has one defined, testable response; PSLVERR support is
               the completer's choice (R4 §3.4), and since R4 §3.4 lets an errored transfer have
               changed state, our rule that nothing changes is stated and asserted.
Impact:        docs/spec.md REQ-IF and REQ-ERR rows; address decode at Gate 3; a window-sweep test.
Decided by:    me
Supersedes:    none

### D-028 — The APB slave never inserts wait states (seed decision 9)
Date:          2026-11-27
Phase:         2
Decision:      PREADY is high in every Access cycle: every transfer completes in two cycles.
Alternatives:  Wait states for a bounded internal reason such as a synchronous-RAM read (frees the
               storage choice, one cycle more per such read); wait states for line-bound reasons
               (the stall rejected in D-025).
Reason:        R4 §3.1.2 allows a fixed two-cycle completer to tie PREADY high; with D-025 and
               D-026 no transfer needs time; one fixed timing rule is simple to test and assert and
               cannot hang the bus.
Impact:        The RX FIFO head must be valid in the Access cycle: Gate 3 shows this with its cycle
               model (D-024) before seed decision 2 (storage) is taken; docs/spec.md REQ-IF rows.
Decided by:    me
Supersedes:    none

### D-029 — A TXDATA write in the cycle of a shifter pop from a full TX FIFO is dropped (spec open item OI-01)
Date:          2026-11-28
Phase:         2
Decision:      The TX FIFO full flag in the Access cycle of a TXDATA write decides alone: when it is
               set, the write is dropped and TX_OVF is set (D-025) even if the shifter pops in that
               cycle.
Alternatives:  Accept the write when the same cycle frees a slot (no byte lost in that race; the
               shifter's pop then feeds the push and TX_OVF logic combinationally, and D-025's
               "finds the TX FIFO full" needs a new meaning).
Reason:        D-025 as worded; the full flag is a registered level, so the accept path has no
               combinational input from the transmitter; the race is avoided by the driver contract
               of D-025 (read the TX-full status bit before writing). The two variants are told apart
               by scripts/apb_slave_model.py (variants block and accept).
Impact:        docs/spec.md REQ-ERR-001, REQ-ERR-002, REQ-IF-006; Gate 3 TX FIFO push logic.
Decided by:    me (no preference given 2026-11-28; the recommendation taken under the standing
               acceptance of proposals of 2026-11-27)
Supersedes:    none

### D-030 — A read of the write-only TXDATA gets PSLVERR with PRDATA 0 and no side effect (spec open item OI-02)
Date:          2026-11-28
Phase:         2
Decision:      A read of a write-only register (TXDATA) is treated as D-027 treats a write to a
               read-only register: it completes with PSLVERR, PRDATA 0, and changes nothing.
Alternatives:  PRDATA 0 with no error (harmless read; read-only and write-only registers would then
               follow different rules).
Reason:        One rule for every offset and access type: an access a register does not support is an
               error with no side effect, checkable by the same window-sweep test and assertion.
Impact:        docs/spec.md REQ-ERR rows and REQ-IF-008; Gate 3 decode.
Decided by:    me (no preference given 2026-11-28; the recommendation taken under the standing
               acceptance of proposals of 2026-11-27)
Supersedes:    none

### D-031 — PSLVERR is low in every cycle that is not the last cycle of a transfer
Date:          2026-11-28
Phase:         2
Decision:      The slave drives PSLVERR low whenever PSEL, PENABLE or PREADY is low.
Alternatives:  PSLVERR defined in the last cycle only, any value elsewhere (R4 §3.4 allows it).
Reason:        R4 §3.4 recommends it; it costs one AND term (PSLVERR = access and error) and is
               checked by one assertion and one formal property; a requester that samples PSLVERR
               early never sees a false error.
Impact:        docs/spec.md REQ-IF-009.
Decided by:    me (2026-11-28)
Supersedes:    none

### D-032 — APB side effects happen only in the cycle that completes the transfer
Date:          2026-11-28
Phase:         2
Decision:      A cycle that completes no transfer (idle, Setup, or an Access cycle with PREADY low)
               changes no register, FIFO entry or flag through the APB; every effect of a transfer
               takes place once, in the cycle with PSEL, PENABLE and PREADY high.
Alternatives:  No rule beyond "exactly one entry per transfer" (a Setup-cycle store or an idle-cycle
               flag set would pass unchecked).
Reason:        One timing rule for every side effect, checked by one assertion and one formal property;
               it excludes double pops and Setup-cycle pushes; it costs nothing, since the decode is
               qualified by PSEL and PENABLE either way.
Impact:        docs/spec.md REQ-IF-012; scripts/apb_slave_model.py plants double_pop, setup_push,
               setup_ctrl, idle_ovf.
Decided by:    me (2026-11-28)
Supersedes:    none
