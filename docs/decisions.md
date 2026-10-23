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
