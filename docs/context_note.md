# Context note — APB UART (Gate 1)

The Gate 1 deliverable (PLANS phase 1): what the block is for, where it sits, and every statement
about it sorted into one of four kinds. Gate 2 starts from this file.

| Kind | Test | What it carries here |
|---|---|---|
| Specified fact | It can be cited from a primary reference | the reference and section, `[Rn §x]` |
| Design choice | We decided it and recorded it | its decision record D-NNN and one alternative |
| Seed proposal or model claim | It is written down, but nothing approved it or no pinned tool showed it | where it is written; the gate that settles it |
| Open question | Nobody has decided it | who decides, by which gate, and the work it blocks |

A line of the seed spec is a proposal, not a fact or a choice: the seed says nothing in it is
approved. A result from a cycle model is a claim, not evidence, until a directed test on the RTL
passes (D-021). The study material is overview only and is never the basis of a requirement (D-021).

## 1. Purpose and system context

A reusable UART peripheral that a CPU controls over APB: it serializes bytes from a TX FIFO,
deserializes bytes into an RX FIFO, reports errors and raises an interrupt (seed spec, Purpose).

It has three interfaces:

| Interface | Other side | Clock relation |
|---|---|---|
| APB3 completer (slave) | the CPU, through the interconnect and an APB bridge | synchronous to PCLK |
| Serial pins `uart_tx`, `uart_rx` | a far-end device | the far end sends from its own clock (F-12) |
| `irq` | the interrupt controller | synchronous to PCLK |

On the Basys 3 demo the APB master is an on-board test sequencer, not a CPU (D-008).

## 2. References

The basis of every fact below. The documents themselves are not in this repository; the
identifiers let anyone obtain the same edition.

| ID | Document |
|---|---|
| R2 | National Semiconductor, *PC16550D UART with FIFOs*, datasheet, 1995, TL/C/8652 |
| R3 | ARM, *PrimeCell UART (PL011) Technical Reference Manual*, r1p5, ARM DDI 0183G |
| R4 | ARM, *AMBA APB Protocol Specification*, ARM IHI 0024D |
| R14 | R. Ginosar, *Metastability and Synchronizers: A Tutorial*, IEEE Design & Test of Computers, Sept./Oct. 2011, pp. 23-35 |

R4 calls the master the Requester and the slave the Completer.

Still needed, each before the gate named. Their publishers refused an automated download on
2026-11-26, so each is obtained by hand and registered (identifier and SHA-256) before it is cited:

| Document | Needed for | By |
|---|---|---|
| FTDI application note AN_232B-05, *Configuring FT232R, FT2232 and FT232B Baud Rates*, and the datasheet of the USB-UART bridge the Basys 3 manual names | the baud error of the board's far end, which bounds the tolerance in O-11 | Gate 2 |
| Digilent, *Basys 3 Reference Manual* | the board clock, the USB-UART connection and the pins (D-008) | Gate 3 |
| C. E. Cummings, *Simulation and Synthesis Techniques for Asynchronous FIFO Design*, SNUG San Jose 2002 | Gray-pointer asynchronous FIFO, if O-10 chooses two clocks | Gate 3 |
| IEEE Std 1800-2023, *SystemVerilog* (the full standard, not the listing) | assertion semantics and how a coverage number is defined (O-16) | Gate 4 |

## 3. Specified facts

Facts about APB bind our design, because it is an APB completer. Facts about the 16550 and the
PL011 describe that IP only: each is a comparison point, and binds our design only if Gate 2 or
Gate 3 chooses the same behaviour.

| # | Fact | Source |
|---|---|---|
| F-01 | APB is not pipelined, and every transfer takes at least two cycles. | [R4 §1.1] |
| F-02 | The SETUP state lasts one clock cycle and always moves to ACCESS on the next rising edge. PADDR and PWRITE, and PWDATA on writes, must not change between SETUP and ACCESS or between cycles in ACCESS. | [R4 §4.1] |
| F-03 | In ACCESS the completer extends a transfer by driving PREADY low. PREADY can take any value while PENABLE is low, so a completer with a fixed two-cycle access can tie PREADY high. | [R4 §3.1.2] |
| F-04 | PSLVERR is valid only in the last cycle of a transfer, when PSEL, PENABLE and PREADY are all high. Driving it low at other times is recommended, not required. | [R4 §3.4] |
| F-05 | A transfer that receives an error might or might not have changed the state of the peripheral; an errored write may still have updated the register; a requester may still use the data of an errored read. | [R4 §3.4] |
| F-06 | A completer is not required to support PSLVERR; where it has none, the requester's input is tied low. | [R4 §3.4] |
| F-07 | The 16550 receiver checks the first stop bit only, whatever the number of stop bits selected. | [R2 §8.1] |
| F-08 | The 16550 baud generator outputs 16 times the baud rate. Its divisor is held in two 8-bit latches, and loading either latch immediately loads the 16-bit baud counter. | [R2 §8.3] |
| F-09 | In the 16550's FIFO mode an overrun occurs only after the FIFO is full and the next character has been completely received in the shift register; that character is overwritten and not transferred to the FIFO. | [R2 §8.4] |
| F-10 | The PL011 has two clocks, PCLK and UARTCLK, and synchronizes control signals in both directions between them with synchronization registers and handshaking logic. | [R3 §2.2.10] |
| F-11 | The PL011 divisor is F_UARTCLK / (16 × baud rate), split into an integer and a fractional register; new divisor values are not used until the current character has been sent or received; an integer divisor of 0 is invalid. | [R3 §3.3.6] |
| F-12 | A UART link is asynchronous: no clock travels with the data, so the far end's transmitter runs from its own clock and `uart_rx` can change at any point of a PCLK cycle. | the 16550 describes its link as asynchronous data communications [R2 §8.1]; the second clause follows from the first |

F-12 is why the receive input needs a synchronizer. How many stages it has is not a fact: it is a
Gate 3 choice (O-15).

## 4. Design choices recorded

### 4.1 Choices about the block

| Record | Choice | One alternative | Applies from |
|---|---|---|---|
| D-001 | One active-low `rst_n`: asserted asynchronously, released through a two-flop reset synchronizer in each clock domain; control state is reset, datapath registers written before read may stay unreset if documented | a fully synchronous reset | every RTL module |
| D-007 | The register map is described once in SystemRDL; the C header and register documentation are generated; the register block RTL is written by hand | generate the RTL as well | Gate 3 |
| D-008 | The FPGA demo drives APB from an on-board test sequencer | a UART-to-APB debug bridge | designed Gate 3, built Gate 10 |
| D-011 | No SystemVerilog interfaces in synthesizable RTL; plain ports or packed structs | allow interfaces and drop Icarus as the second simulator | Gate 5 |
| D-017 | The receiver's start-edge detector updates its previous-sample flop on 16× ticks only | update it every clock and hold an edge flag until the next tick | Gate 3 |
| D-018 | The verification register model is generated from the SystemRDL source, in principle | a hand-written register model | confirmed or rejected at Gate 4, after a probe |
| D-019 | If a write to a full TX FIFO is dropped with a flag, the flag TX_OVF is a W1C bit in INT_STATUS with its own INT_EN bit | the same bit with no enable | Gate 2; conditional on O-03 |
| D-020 | `tx_done` is set when the last stop bit has left the shift register and the TX FIFO is empty | set it when the last byte leaves the FIFO | Gate 2 |

D-019 exists only if O-03 picks drop and flag; if O-03 picks PSLVERR or wait states, Gate 2 revisits
D-019 together with O-03.

### 4.2 Choices about the project and its evidence

| Record | Choice | One alternative |
|---|---|---|
| D-002 | Tiered FPGA flow: Yosys reports, openXC7 bring-up, Vivado timing once per release | Vivado only |
| D-003 | Target v1.0, reached through v0.1 and v0.5 | stop at v0.5 |
| D-004 | Toolchain built from source at the pinned tags | Ubuntu packages |
| D-005 | `main` of this repository is the project line | keep the original line as the base |
| D-006 | A tools-and-structure check at every gate exit | decide tools when each phase starts |
| D-009 | Apache-2.0 | Solderpad Hardware License 2.1 |
| D-010 | CI on a pinned toolchain image on every push | build the tools in every CI run |
| D-012 | UVM runs on Verilator with uvm-verilator | UVM on EDA Playground only |
| D-013 | Pinned toolchain extended for the production-level checks | add each tool when its gate starts |
| D-014 | License and copyright information on every file | headers from the first RTL file on |
| D-015 | Quality rules for every artifact; light CI now | add one check per error after it is found |
| D-016 | Verilator PROCASSINIT on for RTL, waived for testbenches | waive it everywhere |
| D-021 | Every requirement names its basis; behaviour is established by evidence on the pinned tools | treat the study material as the reference design |

## 5. Seed proposals and model claims

### 5.1 Seed proposals (become requirements only at Gate 2)

Everything in `docs/uart_spec_seed.md` is a proposal: the frame (8 data bits, optional even or odd
parity, 1 or 2 stop bits, LSB first), the programmable divisor and 16× oversampling on RX, the
two-flop receive synchronizer, the parameterized synchronous FIFOs on a simple dual-port RAM, the
three error kinds, the status and interrupt sets, the draft register map, and the candidate
non-goals (among them 5 to 7 data bits). Gate 2 accepts, changes or rejects each one and records the
basis of the requirement that results (D-021).

### 5.2 Model claims (become evidence only as RTL tests, Gate 5 on)

| Claim | Where it is written | What settles it |
|---|---|---|
| As proposed (stop bit decided at the last sample, previous-sample flop updated on every tick), the receiver loses the next start edge in a back-to-back burst when the far end is fast beyond a limit, and the usual ±2 % at each end does not fit | `project_status.md`, open decision "RX re-arm" (limits and options) | O-11 at Gate 3, then a directed test against the RTL (D-021) |

The model was written for the proposed receiver. D-017 changed when the previous-sample flop
updates, so the Gate 2-3 double modelling (D-021) re-runs this claim on the receiver Gate 3 chooses.

## 6. Open questions

All of them are the owner's to decide. The gate follows one test: if software, the APB bus or the
far end on the line would see the difference, the requirement comes first (Gate 2); if only the
microarchitecture, area or verification changes, it belongs to Gate 3. Two items recorded for Phase 3
have an external face, so Gate 2 states the requirement and Gate 3 the design.

| # | Question | Gate | Who would see it | Blocks |
|---|---|---|---|---|
| O-01 | FIFO depth: default, allowed range, power of two only? (seed 1) | 2 | software: threshold range and level fields | field widths; pointer design (lap bit or wrap compare) |
| O-02 | FIFO storage: inferred RAM or flops? (seed 2) | 3 | nobody outside, while reads stay zero-wait | FIFO microarchitecture and its read latency |
| O-03 | Write to TXDATA while the TX FIFO is full: drop and flag, PSLVERR, or wait states? (seed 3) | 2 | the bus (PSLVERR or PREADY) or software (a flag) | D-019 (TX_OVF); the PREADY logic; decide with O-09 |
| O-04 | Read of RXDATA while the RX FIFO is empty: 0, last value, or PSLVERR? (seed 4) | 2 | the bus: PRDATA and PSLVERR | pop gating and the read mux |
| O-05 | RX overrun: drop the new byte or overwrite the oldest? (seed 5) | 2 | software: which bytes it receives | RX FIFO write side |
| O-06 | Error and interrupt clear: W1C, clear on read, or both? (seed 6) | 2 | software: driver idioms | INT_STATUS block; SystemRDL access types |
| O-07 | Unmapped or illegal address access: PSLVERR or silent? (seed 7) | 2 | the bus | address decode |
| O-08 | BAUDDIV of 0 or too small: forbid, clamp or flag; PSLVERR on the write? (seed 8) | 2 | software (read-back, PSLVERR) and the line | baud generator guard |
| O-09 | Does the completer insert wait states anywhere, or is it always zero-wait? (seed 9) | 2 | the bus: timing of every slave behind the bridge | PREADY logic; a registered PRDATA; decide with O-03 |
| O-10 | One clock in v0.1 and an async FIFO later, or two clocks from the start? (seed 10; recorded for Phase 3) | 3, with the v0.1 clock stated as a Gate 2 assumption | a second clock adds a port | CDC design; reset synchronizers per domain (D-001); O-12 |
| O-11 | RX re-arm in a back-to-back burst: re-arm in STOP, a restarted RX counter, or a stated lower limit (§5.2; recorded for Phase 3) | 3, with the required far-end tolerance stated at Gate 2 | the far end: the tolerance it may have | RX state machine |
| O-12 | Scope of the structural CDC script (no free CDC sign-off tool, D-013) | 3, with O-10 | nobody outside | Gate 10 CDC review |
| O-13 | Source of a TX level interrupt: the seed lists a TX-empty interrupt and D-020's reason relies on a TX level interrupt, but no INT_STATUS bit for it is proposed yet | 2 | software: when it may refill the TX FIFO | INT_STATUS and INT_EN maps |
| O-14 | A status bit that shows a BAUDDIV write not yet in use (if the divisor change is deferred to a frame boundary) | 2 | software: when the new rate applies | STATUS map; baud generator update rule |
| O-15 | Number of stages in the `uart_rx` synchronizer, from the MTBF at the chosen clock: MTBF = e^(S/τ) / (T_W · F_C · F_D), where S is the resolution time the stages give [R14 p. 28] | 3 | nobody outside, beyond latency | receiver front end |
| O-16 | What Verilator's `get_inst_coverage()` number means against IEEE 1800 | before Gate 4 names a coverage target | nobody outside | coverage targets in the verification plan |
| O-17 | A soft CPU running the C driver on the board | after v1.0 | nobody outside | — |

## 7. Learning checklist

| # | Topic | State |
|---|---|---|
| M0 | Toolchain probes: vacuity, `$past`, ASSUME, BMC depth (Gate 0) | done; checkpoint round deferred to Gate 8 entry |
| L1 | System context | done 2026-10-12 |
| L2 | APB3 protocol | done 2026-10-22 |
| L3 | UART frame and transmitter | done 2026-10-23 |
| L4 | Baud generation | done 2026-10-25 |
| L5 | RX synchronizer and start-bit detection | done 2026-10-26 |
| L6 | FIFOs | done 2026-10-27 |
| L7 | Registers and interrupts | done 2026-11-01 |
| L8 | Verification strategy | done 2026-11-02; checkpoint round deferred to Gate 4 entry |

Gate 1 checkpoint: rounds for Set 0, L1 to L7 and G1 (this note's sorting) are done, each explained
cold by the owner and graded. The grades and the topics to ask again at Gate 2 entry are kept in the
owner's private learning log.
