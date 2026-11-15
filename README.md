<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 murugan-15
-->
# APB UART subsystem

A UART peripheral with FIFOs, controlled over an AMBA APB3 bus, built in gated stages toward a
verified block that runs on a Basys 3 FPGA board.

**Status: Gate 1 of 12 (learning the block). There is no RTL yet.** The live state is in
[`docs/project_status.md`](docs/project_status.md). Nothing in this file is claimed beyond what the
commands below reproduce.

## What exists today

| Piece | Where | What it gives |
|---|---|---|
| Pinned open-source toolchain | [`scripts/install_toolchain.sh`](scripts/install_toolchain.sh), [`requirements-tools.txt`](requirements-tools.txt) | The same tool versions on every machine: Verilator, Icarus Verilog, Yosys, SymbiYosys, Yices, Z3, and the tools for coverage reports, mutation coverage, equivalence, UVM, register generation and lint (versions in [`docs/conventions.md`](docs/conventions.md) §1.1) |
| Capability probes | [`tb/probes/`](tb/probes/README.md) | 27 small tests of what each tool can and cannot do. Most keep a run that must fail, so a tool that silently ignores a feature shows up |
| Conventions | [`docs/conventions.md`](docs/conventions.md) | Coding, testbench, assertion and formal rules, each backed by a probe or a bug-log entry |
| Decision log | [`docs/decisions.md`](docs/decisions.md) | One record per decision, with the alternatives that were rejected and why |
| Bug log | [`docs/bug_log.md`](docs/bug_log.md) | Real bugs only, each with its evidence and the check that now prevents it |
| Seed specification | [`docs/uart_spec_seed.md`](docs/uart_spec_seed.md) | The starting point for the requirements. Nothing in it is approved yet |

## Reproduce it

On Ubuntu 24.04:

```sh
sudo make toolchain   # builds the pinned tools into /opt/eda (an estimated 40 to 60 minutes on four cores the first time; not timed end to end)
make probe            # runs every probe and compares with tb/probes/expected.txt
make license          # every file carries SPDX license information
make check-docs       # the documents agree with each other and with the repository
```

`make probe` must end with `Probe results match baseline.` The baseline is
**48 PASS / 20 FAIL / 0 UNAVAIL** over 68 checks. Each FAIL is a known limitation of a tool, pinned
on purpose so that a tool update that changes it is noticed; the conventions say how the design
works around each one.

## Plan

The project advances through thirteen phases (0 to 12), from tool checks and requirements to FPGA bring-up and a design review,
and is released in three cuts (decision D-003):

| Cut | Adds | State |
|---|---|---|
| v0.1 | specification, architecture, RTL, directed self-checking tests, lint, resource report | not started |
| v0.5 | constrained-random tests with logged seeds, assertions, coverage, CI | not started |
| v1.0 | formal results, a UVM testbench on Verilator, FPGA bring-up evidence, design review | not started |

Two limits are known already and will be stated with the results: no free tool does CDC sign-off
(a written review and a structural script will stand in), and sign-off timing comes from Vivado on
a separate machine, so its reports will be committed rather than regenerated in CI.

## License

Apache-2.0. See [`LICENSE`](LICENSE).
