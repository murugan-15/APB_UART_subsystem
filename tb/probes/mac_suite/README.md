# Original M0 probe suite (Mac host)

The first Gate 0 probe suite, written and baselined on the Mac host (Apple Silicon,
Homebrew toolchain) on 2026-10-10. It is kept here as a separate suite; the project's
own baseline is the suite one level up (`tb/probes/`, `make probe`).

It covers four constructs the main suite does not probe yet (`conventions.md` §2.3):
classes with queues and mailboxes (p01), covergroups (p03), `--coverage` (p07) and
FST waveform dumps (p08). Porting those into the main suite is milestone M0b.

Run it with `make probe-mac` (results in `build/reports/probes_mac.txt`, compared
against `expected.txt` here). The files are the originals; `probe.sh` differs only in
four path lines so it runs from this folder and writes to `build/probes_mac/`.

## Cloud-host run, 2026-10-14

`make probe-mac` (tools from `/opt/eda`): 23 PASS / 11 FAIL / 1 UNAVAILABLE, exit 1.
Every result matches the Mac baseline except the three FST checks, and those failures
come from the host setup, not from the tools:

| Check | Result here | Cause (from the log) |
|---|---|---|
| `p08_wave_dump verilator` | FAIL | `fstcpp_writer.cpp: fatal error: lz4.h: No such file` — the container has no `liblz4-dev` |
| `p08_fst verilator` | FAIL | follows from the build failure above |
| `p08_fst icarus` | FAIL | Icarus wrote `p08.fst`, but the check calls `xxd`, which is not installed here |

The baseline was not changed.
