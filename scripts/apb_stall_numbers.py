#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
"""Worst-case stall numbers quoted in D-025 (seed decision 3, the rejected stall option).

Worst-case PREADY stall of a TXDATA write to a full TX FIFO under the stall option:
the write waits until the shifter takes the next byte, at most one whole character.
Basis: hardware divisor D = round(PCLK / (16 * baud)), 16 ticks per bit; the extra
wait for the shared tick (up to D cycles) is added for the bound.
"""
FORMATS = {"8N1": 10, "8E2": 12}  # bits per character: start + 8 data + parity + stops

def stall(pclk, baud, fmt):
    d = round(pclk / (16 * baud))
    cycles = FORMATS[fmt] * 16 * d + d
    return d, cycles, cycles / pclk * 1e6

for pclk, baud, fmt in [(50e6, 115200, "8N1"), (50e6, 9600, "8E2"), (100e6, 115200, "8N1")]:
    d, cyc, us = stall(pclk, baud, fmt)
    print(f"PCLK {pclk/1e6:.0f} MHz, {baud} baud, {fmt}: D = {d}, worst stall {cyc} cycles = {us:.2f} us")
