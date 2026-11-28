#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
"""Cycle model of the APB slave behaviour decided in D-025 to D-028 (D-024: one executable model).

A claim, not evidence (D-021, D-024): it becomes evidence only through the Gate 5 directed tests
against the RTL. The model has two parts that share no code:
  Slave    the behaviour as decided: two-cycle transfers (D-028), TXDATA full -> drop + TX_OVF
           (D-025), RXDATA empty -> 0 and no pop (D-026), full decode with PSLVERR, PRDATA 0 and no
           side effect on an unmapped offset or a write to a read-only register (D-027).
  Checker  sees only the bus pins and the two FIFO levels, contents and the INT_STATUS word before
           and after each cycle, and asserts each requirement row of the draft (REQ ids in messages).

Conditions, as the rows state them: "TX FIFO full" is the TX FIFO full flag (level == depth) in the
Access cycle of the write; "RX FIFO empty" is the RX FIFO empty flag (level == 0) in the Access cycle of
the read. The shifter's pop and the receiver's push in the same cycle are applied after the APB access
reads those flags (variant 'block', the literal reading of D-025); variant 'accept' lets a write in the
cycle of a shifter pop on a full FIFO push (an open item for the owner).

Register map: the seed draft map (uart_spec_seed.md; finalised at Gate 3). Window: 4 KB (a parameter,
open item; any width gives the same results here). TXDATA is write-only; its read response is an open
item, modelled as PSLVERR with PRDATA 0 (variant 'wo_err') or as 0 with no error ('wo_zero').

Usage:  python3 scripts/apb_slave_model.py              all cases on both variants, then every planted bug
        python3 scripts/apb_slave_model.py --plant NAME one planted bug only (must FAIL)
Exit 0 only when the correct model passes every case and every planted bug is caught.
"""
import argparse
import random
import sys

DEPTH = 4
WINDOW = 0x1000
TXDATA, RXDATA, STATUS, CTRL, BAUDDIV, INT_EN, INT_STATUS = 0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x18
RW = {CTRL, BAUDDIV, INT_EN}
RO = {RXDATA, STATUS}
WO = {TXDATA}
TX_OVF = 1 << 0          # bit position is a Gate 3 choice; the model needs only one bit

PLANTS = {
    'stall':          'PREADY low for one cycle on a write to a full TX FIFO (breaks REQ-IF-001)',
    'push_full':      'a write to a full TX FIFO overwrites the newest entry (breaks REQ-ERR-001)',
    'no_ovf':         'TX_OVF not set on a write to a full TX FIFO (breaks REQ-ERR-002)',
    'err_full':       'PSLVERR on a write to a full TX FIFO (breaks REQ-IF-002)',
    'stale_read':     'an empty RXDATA read returns the last popped byte (breaks REQ-IF-003)',
    'pop_empty':      'an empty RXDATA read drops the byte the receiver pushes in that cycle (breaks REQ-ERR-003)',
    'double_pop':     'a RXDATA read pops in Setup as well as Access (breaks REQ-IF-005)',
    'partial_decode': 'decode on PADDR[4:2] only: 0x104 aliases RXDATA (breaks REQ-ERR-004, REQ-ERR-006)',
    'ro_write':       'a write to STATUS completes without PSLVERR (breaks REQ-ERR-005)',
    'err_data':       'an errored read returns a non-zero value (breaks REQ-IF-007)',
    'err_side':       'a write to RXDATA gets PSLVERR but sets TX_OVF (breaks REQ-ERR-006)',
    'err_idle':       'PSLVERR high in a Setup cycle (breaks REQ-IF-008)',
}


class Slave:
    def __init__(self, variant, wo, plant):
        self.variant, self.wo, self.plant = variant, wo, plant
        self.tx, self.rx = [], []
        self.regs = {CTRL: 0, BAUDDIV: 0, INT_EN: 0, INT_STATUS: 0}
        self.last_pop = 0x5A
        self.stalled = False

    def status(self):
        return (len(self.tx) == 0) | (len(self.tx) == DEPTH) << 1 | (len(self.rx) == 0) << 2 | (len(self.rx) == DEPTH) << 3

    def cycle(self, psel, penable, pwrite, paddr, pwdata, shifter_pop, rx_push):
        """One PCLK cycle: outputs, then the state update at the clock edge."""
        tx_full, rx_empty = len(self.tx) == DEPTH, len(self.rx) == 0
        off = paddr & 0x1C if self.plant == 'partial_decode' else paddr
        mapped = off < WINDOW and off in (RW | RO | WO | {INT_STATUS})
        access = psel and penable
        err_cond = (not mapped) or (pwrite and off in RO) or (not pwrite and off in WO and self.wo == 'wo_err')
        if self.plant == 'ro_write' and pwrite and off == STATUS:
            err_cond = False
        pready = not (self.plant == 'stall' and access and pwrite and off == TXDATA and tx_full and not self.stalled)
        self.stalled = (not pready)
        done = access and pready
        pslverr = done and err_cond
        if self.plant == 'err_full' and done and pwrite and off == TXDATA and tx_full:
            pslverr = True
        if self.plant == 'err_idle' and psel and not penable:
            pslverr = True
        prdata = 0
        pop_rx = push_tx = False
        if done and not pwrite:
            if err_cond:
                prdata = 0xEE if self.plant == 'err_data' else 0
            elif off == RXDATA:
                if rx_empty:
                    prdata = self.last_pop if self.plant == 'stale_read' else 0
                else:
                    prdata, pop_rx = self.rx[0], True
            elif off == STATUS:
                prdata = self.status()
            elif off in self.regs:
                prdata = self.regs[off]
        if self.plant == 'double_pop' and psel and not penable and not pwrite and off == RXDATA and not rx_empty:
            pop_rx = True
        set_ovf = False
        if done and pwrite and not err_cond:
            if off == TXDATA:
                room = (not tx_full) or (self.variant == 'accept' and shifter_pop)
                if room:
                    push_tx = True
                else:
                    set_ovf = self.plant != 'no_ovf'
                    if self.plant == 'push_full':
                        self.tx[-1] = pwdata & 0xFF
            elif off == INT_STATUS:
                self.regs[INT_STATUS] &= ~pwdata
            elif off in RW:
                self.regs[off] = pwdata
        if self.plant == 'err_side' and pslverr and pwrite and off == RXDATA:
            set_ovf = True
        # clock edge: the APB access saw the flags above; then the shifter and the receiver act
        if pop_rx:
            self.last_pop = self.rx.pop(0)
        if shifter_pop and self.tx:
            self.tx.pop(0)
        if push_tx:
            self.tx.append(pwdata & 0xFF)
        if rx_push is not None:
            if self.plant == 'pop_empty' and done and not pwrite and off == RXDATA and rx_empty:
                pass
            elif len(self.rx) < DEPTH:
                self.rx.append(rx_push)
        if set_ovf:
            self.regs[INT_STATUS] |= TX_OVF
        return pready, pslverr, prdata


def observe(s):
    return list(s.tx), list(s.rx), dict(s.regs)


class Checker:
    """Asserts the draft requirement rows from pins and before/after observations only."""
    def __init__(self, variant, wo):
        self.variant, self.wo, self.fails = variant, wo, []
        self.phase = 'IDLE'

    def fail(self, req, msg):
        self.fails.append(f'{req}: {msg}')

    def check(self, pins, out, before, after, shifter_pop, rx_push):
        psel, penable, pwrite, paddr, pwdata = pins
        pready, pslverr, prdata = out
        tx0, rx0, r0 = before
        tx1, rx1, r1 = after
        access = psel and penable
        if access and not pready:
            self.fail('REQ-IF-001', f'PREADY low in an Access cycle at 0x{paddr:X}')
        if pslverr and not (access and pready):
            self.fail('REQ-IF-008', 'PSLVERR high outside the last cycle of a transfer')
        if not (access and pready):                      # a cycle that completes no transfer has no APB side effect
            exp_tx = tx0[1:] if shifter_pop and tx0 else tx0
            exp_rx = rx0 + [rx_push] if rx_push is not None and len(rx0) < DEPTH else rx0
            if tx1 != exp_tx or rx1 != exp_rx or r1 != r0:
                self.fail('REQ-IF-005', 'state changed in a cycle that completes no transfer')
            return
        unmapped = paddr not in (TXDATA, RXDATA, STATUS, CTRL, BAUDDIV, INT_EN, INT_STATUS)
        ro_write = pwrite and paddr in (RXDATA, STATUS)
        wo_read = (not pwrite) and paddr == TXDATA
        expect_err = unmapped or ro_write or (wo_read and self.wo == 'wo_err')
        if unmapped and not pslverr:
            self.fail('REQ-ERR-004', f'no PSLVERR at unmapped offset 0x{paddr:X}')
        if ro_write and not pslverr:
            self.fail('REQ-ERR-005', f'no PSLVERR on a write to read-only 0x{paddr:X}')
        if pslverr and not expect_err:
            self.fail('REQ-ERR-004', f'PSLVERR on a legal access at 0x{paddr:X}')
        if expect_err:
            if not pwrite and prdata != 0:
                self.fail('REQ-IF-007', f'errored read at 0x{paddr:X} returned 0x{prdata:X}')
            # no side effect: only the shifter's pop and the receiver's push may change state
            exp_tx = tx0[1:] if shifter_pop and tx0 else tx0
            exp_rx = rx0 + [rx_push] if rx_push is not None and len(rx0) < DEPTH else rx0
            if tx1 != exp_tx or rx1 != exp_rx or r1 != r0:
                self.fail('REQ-ERR-006', f'errored access at 0x{paddr:X} changed state')
            return
        if wo_read:                                      # variant wo_zero: 0, no error, no side effect
            exp_tx = tx0[1:] if shifter_pop and tx0 else tx0
            exp_rx = rx0 + [rx_push] if rx_push is not None and len(rx0) < DEPTH else rx0
            if prdata != 0 or tx1 != exp_tx or rx1 != exp_rx or r1 != r0:
                self.fail('OI-02', 'a TXDATA read (variant wo_zero) returned non-zero or changed state')
            return
        if pwrite and paddr == TXDATA:
            full = len(tx0) == DEPTH
            if pslverr:
                self.fail('REQ-IF-002', 'PSLVERR on a TXDATA write')
            accepted = (not full) or (self.variant == 'accept' and shifter_pop)
            base = tx0[1:] if shifter_pop and tx0 else list(tx0)
            if accepted:
                if tx1 != base + [pwdata & 0xFF]:
                    self.fail('REQ-IF-006', 'a TXDATA write with room did not push exactly one byte')
            else:
                if tx1 != base:
                    self.fail('REQ-ERR-001', 'a TXDATA write to a full TX FIFO changed the FIFO')
                if not r1[INT_STATUS] & TX_OVF:
                    self.fail('REQ-ERR-002', 'TX_OVF not set by a TXDATA write to a full TX FIFO')
        if not pwrite and paddr == RXDATA:
            empty = len(rx0) == 0
            if pslverr:
                self.fail('REQ-IF-004', 'PSLVERR on a RXDATA read')
            if empty:
                if prdata != 0:
                    self.fail('REQ-IF-003', f'empty RXDATA read returned 0x{prdata:X}')
                exp = [rx_push] if rx_push is not None else []
                if rx1 != exp:
                    self.fail('REQ-ERR-003', 'empty RXDATA read changed the RX FIFO')
            else:
                exp = [rx0[1:] + ([rx_push] if rx_push is not None and len(rx0) < DEPTH else [])]
                if rx_push is not None and len(rx0) == DEPTH:  # pop and push on a full RX FIFO: seed decision 5
                    exp.append(rx0[1:] + [rx_push])            # (overrun policy, open), so either outcome passes
                if prdata != rx0[0] or rx1 not in exp:
                    self.fail('REQ-IF-005', 'a RXDATA read with data did not return the head and pop exactly one')


def transfer(s, c, pwrite, paddr, pwdata=0, sp=(False, False), rp=(None, None)):
    """One APB transfer: Setup, then Access cycles until PREADY (at most 4)."""
    for i, pen in enumerate([False, True, True, True, True]):
        pins = (True, pen, pwrite, paddr, pwdata)
        before = observe(s)
        k = min(i, 1)
        out = s.cycle(*pins, sp[k], rp[k])
        c.check(pins, out, before, observe(s), sp[k], rp[k])
        if pen and out[0]:
            return out
    return out


def idle(s, c, sp=False, rp=None):
    pins = (False, False, False, 0, 0)
    before = observe(s)
    out = s.cycle(*pins, sp, rp)
    c.check(pins, out, before, observe(s), sp, rp)


def run(variant, wo, plant, seed=1):
    s, c = Slave(variant, wo, plant), Checker(variant, wo)
    # directed cases
    for b in range(DEPTH + 2):                           # fill, then two writes to a full FIFO
        transfer(s, c, True, TXDATA, 0x30 + b)
    transfer(s, c, True, TXDATA, 0x77, sp=(False, True))  # write in the cycle of a shifter pop, FIFO full
    for _ in range(DEPTH + 1):
        idle(s, c, sp=True)
    transfer(s, c, False, RXDATA)                        # empty read
    transfer(s, c, False, RXDATA, rp=(None, 0x41))       # empty read in the cycle of a receiver push
    transfer(s, c, False, RXDATA)                        # that byte, read next
    for v in (0x11, 0x22):
        idle(s, c, rp=v)
    transfer(s, c, False, RXDATA)
    transfer(s, c, True, INT_STATUS, TX_OVF)             # clear TX_OVF
    transfer(s, c, True, RXDATA, 0xFF)                   # read-only writes
    transfer(s, c, True, STATUS, 0xFF)
    transfer(s, c, False, TXDATA)                        # write-only read
    for off in range(0, WINDOW, 1):                      # window sweep, reads and writes, every byte offset
        if off % 4 or off > INT_STATUS:
            transfer(s, c, False, off)
            transfer(s, c, True, off, 0xA5)
    # random cases
    rnd = random.Random(seed)
    offs = [TXDATA, RXDATA, STATUS, CTRL, BAUDDIV, INT_EN, INT_STATUS, 0x1C, 0x02, 0x104, 0xFFC]
    for _ in range(4000):
        if rnd.random() < 0.3:
            idle(s, c, rnd.random() < 0.3, rnd.randrange(256) if rnd.random() < 0.3 else None)
        else:
            sp = (rnd.random() < 0.2, rnd.random() < 0.2)
            rp = tuple(rnd.randrange(256) if rnd.random() < 0.2 else None for _ in range(2))
            transfer(s, c, rnd.random() < 0.5, rnd.choice(offs), rnd.randrange(256), sp, rp)
    return c.fails


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--plant', choices=sorted(PLANTS))
    a = ap.parse_args()
    if a.plant:
        fails = run('block', 'wo_err', a.plant)
        print(f'{"CAUGHT" if fails else "MISSED"}  {a.plant}: {PLANTS[a.plant]}' + (f'\n        first: {fails[0]}' if fails else ''))
        return 0 if fails else 1
    bad = 0
    for variant in ('block', 'accept'):
        for wo in ('wo_err', 'wo_zero'):
            fails = run(variant, wo, None)
            print(f'{"PASS" if not fails else "FAIL"}    correct model, variant {variant}, {wo}: {len(fails)} assertion failures')
            for f in fails[:3]:
                print(f'        {f}')
            bad += bool(fails)
    caught = 0
    for name in sorted(PLANTS):
        fails = run('block', 'wo_err', name)
        print(f'{"CAUGHT" if fails else "MISSED"}  {name}: {PLANTS[name]}' + (f'\n        first: {fails[0]}' if fails else ''))
        caught += bool(fails)
    print(f'apb_slave_model: correct model {"passes" if not bad else "FAILS"} on 4 variants; {caught} of {len(PLANTS)} planted bugs caught')
    return 0 if not bad and caught == len(PLANTS) else 1


if __name__ == '__main__':
    sys.exit(main())
