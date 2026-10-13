# Seed Spec — APB UART with FIFOs (Project 1)

Input to Phase 2. Nothing here is approved; it is a starting point. Items under
**Open decisions** are mine to make before Phase 3 closes.

## Purpose

A reusable UART peripheral that a CPU controls over APB: it serializes bytes from a TX FIFO,
deserializes bytes into an RX FIFO, reports errors, and raises interrupts.

## Proposed feature set

| Area | Seed content |
|---|---|
| Bus | APB slave (APB3: `psel`, `penable`, `pwrite`, `paddr`, `pwdata`, `prdata`, `pready`, `pslverr`) |
| Frame | 8 data bits; optional parity (even/odd); 1 or 2 stop bits; LSB first |
| Baud | Programmable divisor register; 16× oversampling on RX |
| TX path | TX FIFO → shift register + FSM → `uart_tx` line |
| RX path | `uart_rx` → 2-flop synchronizer → start-bit detection + mid-bit sampling → RX FIFO |
| Storage | Parameterized synchronous FIFO; storage is a simple dual-port RAM module (the "RAM" part of the project) |
| Errors | Framing error, parity error, RX overrun |
| Status | TX empty/full, RX empty/full, busy, error flags |
| Interrupts | Enables + sticky status for TX-empty, RX-not-empty (or threshold), errors; single `irq` output |
| Optional (v1.0) | Async FIFO between APB clock and a separate UART clock (CDC talking point); loopback mode |

## Draft register map (to be finalized in Phase 3)

| Offset | Name | Access | Purpose |
|---|---|---|---|
| 0x00 | TXDATA | W | Push byte to TX FIFO |
| 0x04 | RXDATA | R | Pop byte from RX FIFO |
| 0x08 | STATUS | R (+W1C on error bits?) | FIFO flags, busy, errors |
| 0x0C | CTRL | R/W | Enable TX/RX, parity, stop bits, loopback |
| 0x10 | BAUDDIV | R/W | Baud divisor |
| 0x14 | INT_EN | R/W | Interrupt enables |
| 0x18 | INT_STATUS | R/W1C | Interrupt status |

## Open decisions

1. FIFO depth default and allowed range; power-of-two only?
2. FIFO storage: inferred RAM module vs register array (BRAM/LUTRAM vs flops — PPA tradeoff).
3. Write to TXDATA when TX FIFO is full: drop + error flag, `pslverr`, or wait states via `pready`?
4. Read of RXDATA when RX FIFO is empty: return 0, last value, or `pslverr`?
5. RX overrun policy: drop new byte or overwrite oldest?
6. Error and interrupt clear semantics: W1C, clear-on-read, or both?
7. Illegal/unmapped address access: `pslverr` or silent?
8. Baud divisor of 0 or too small: forbid, clamp, or flag?
9. Does the APB interface insert wait states (`pready` low) anywhere, or always zero-wait?
10. Single clock (v0.1) and async FIFO later, or dual clock from the start?

## Candidate non-goals (v0.1)

Hardware flow control (RTS/CTS), auto-baud, DMA interface, 5–7 data bits, break detection.
