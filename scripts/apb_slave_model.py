#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
"""Cycle model of the APB slave behaviour decided in D-019 and D-025 to D-031 (D-024: one executable model).

A claim, not evidence (D-021, D-024): it becomes evidence only through the Gate 5 directed tests
against the RTL. Two parts with no behaviour code in common (they share only the register map
constants below, so a wrong offset constant would pass both):
  Slave    the behaviour as decided: two-cycle transfers (D-028); TXDATA write when the TX FIFO is full
           dropped and TX_OVF set (D-025), also in the cycle of a shifter pop (D-029); RXDATA read when
           the RX FIFO is empty returns 0 and does not pop (D-026); full decode with PSLVERR, PRDATA 0 and
           no side effect on an unmapped offset, a write to a read-only or a read of a write-only
           register (D-027, D-030); PSLVERR low outside the last cycle (D-031); INT_STATUS W1C (D-019).
           The RX FIFO is a storage array with read and write pointers one bit wider than the index, so
           an ungated pop can be planted.
  Checker  sees the bus pins, and the FIFO contents and register values before and after each cycle;
           it predicts the whole next state of every cycle and reports a mismatch under its row ID
           (docs/gate2/spec_apb_rows.md in the private notes repository; docs/spec.md once created).

Conditions, as the rows state them: "TX FIFO full" is the TX FIFO full flag (level equal to the depth)
in the Access cycle of the write; "RX FIFO empty" is the RX FIFO empty flag (level 0) in the Access cycle
of the read. The shifter's pop and the receiver's push of that cycle act after the APB access has read
those flags. Register map: the seed draft map (finalised at Gate 3). Window: 4 KB here (a parameter,
OI-03). Not modelled: the RX overrun policy (seed decision 5; a push into a full RX FIFO is dropped here,
and with a pop in the same cycle either outcome passes, OI-04), read values of STATUS and of the R/W
registers and the value a R/W write stores (OI-06).

Usage:  python3 scripts/apb_slave_model.py              correct model, coverage counts, every planted bug
        python3 scripts/apb_slave_model.py --plant NAME one planted bug only (must be caught)
Exit 0 only when the correct model passes, every directed corner case ran, and every planted bug is
caught first under the row it names.
"""
import argparse
import random
import sys

DEPTH = 4
WINDOW = 0x1000
TXDATA, RXDATA, STATUS, CTRL, BAUDDIV, INT_EN, INT_STATUS = 0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x18
TX_OVF = 1 << 0          # bit position is a Gate 3 choice; the model needs only one bit
REGS = (TXDATA, RXDATA, STATUS, CTRL, BAUDDIV, INT_EN, INT_STATUS)

PLANTS = {                                   # name: (row it breaks, description)
    'stall':        ('REQ-IF-001', 'PREADY low for one cycle on a write to a full TX FIFO'),
    'err_full':     ('REQ-IF-002', 'PSLVERR on a write to a full TX FIFO'),
    'stale_read':   ('REQ-IF-003', 'an empty RXDATA read returns the last popped byte'),
    'err_rxread':   ('REQ-IF-004', 'PSLVERR on every RXDATA read'),
    'head_wrong':   ('REQ-IF-005', 'a RXDATA read returns the head with bit 0 inverted'),
    'double_pop':   ('REQ-IF-012', 'a RXDATA read pops in Setup as well as in Access'),
    'setup_push':   ('REQ-IF-012', 'a TXDATA write pushes in Setup as well as in Access'),
    'setup_ctrl':   ('REQ-IF-012', 'a CTRL write stores PWDATA already in its Setup cycle'),
    'idle_ovf':     ('REQ-IF-012', 'TX_OVF set in an idle cycle while the TX FIFO is full'),
    'push_corrupt': ('REQ-IF-007', 'a TXDATA write pushes PWDATA[7:0] with bit 0 inverted'),
    'err_data':     ('REQ-IF-008', 'an errored read returns 0xEE, not 0'),
    'err_ctrl':     ('REQ-IF-009', 'PSLVERR on a write to CTRL'),
    'err_idle':     ('REQ-IF-010', 'PSLVERR high in a Setup cycle'),
    'ovf_always':   ('REQ-IF-011', 'TX_OVF set by every TXDATA write, accepted or not'),
    'status_pop':   ('REQ-IF-011', 'a STATUS read pops the RX FIFO'),
    'ctrl_push':    ('REQ-IF-011', 'a CTRL write also pushes the TX FIFO'),
    'w1c_dead':     ('REQ-FUNC-001', 'a write to INT_STATUS clears nothing'),
    'w1c_zero':     ('REQ-FUNC-001', 'a write to INT_STATUS clears every bit, whatever PWDATA holds'),
    'push_full':    ('REQ-ERR-001', 'a write to a full TX FIFO overwrites the newest entry'),
    'accept_pop':   ('REQ-ERR-001', 'a write in the cycle of a shifter pop from a full TX FIFO is pushed (the rejected option of D-029)'),
    'no_ovf':       ('REQ-ERR-002', 'TX_OVF not set by a write to a full TX FIFO'),
    'pop_ungated':  ('REQ-ERR-003', 'the RXDATA pop is not gated by the empty flag: the read pointer passes the write pointer'),
    'partial_decode': ('REQ-ERR-004', 'decode on PADDR[4:2] only: 0x104 aliases RXDATA'),
    'ro_write':     ('REQ-ERR-005', 'a write to STATUS completes without PSLVERR'),
    'wo_read':      ('REQ-ERR-006', 'a TXDATA read completes without PSLVERR (the rejected option of D-030)'),
    'err_side':     ('REQ-ERR-007', 'a write to RXDATA gets PSLVERR but sets TX_OVF'),
    'ovf_nodecode': ('REQ-ERR-007', 'TX_OVF set by any write to the TXDATA word (0x00 to 0x03) when the TX FIFO is full'),
}


class Slave:
    def __init__(self, plant):
        self.plant = plant
        self.tx = []
        self.mem, self.rd, self.wr = [0] * DEPTH, 0, 0          # RX FIFO: pointers modulo 2 * DEPTH
        self.regs = {CTRL: 0, BAUDDIV: 0, INT_EN: 0, INT_STATUS: 0}
        self.last_pop = 0x5A
        self.stalled = False

    def rx_level(self):
        return (self.wr - self.rd) % (2 * DEPTH)

    def rx_list(self):
        return [self.mem[(self.rd + i) % DEPTH] for i in range(self.rx_level())]

    def cycle(self, psel, penable, pwrite, paddr, pwdata, shifter_pop, rx_push):
        """One PCLK cycle: outputs, then the state update at the clock edge."""
        p = self.plant
        tx_full, rx_empty = len(self.tx) == DEPTH, self.rx_level() == 0
        off = paddr & 0x1C if p == 'partial_decode' else paddr
        err = (off not in REGS) or (pwrite and off in (RXDATA, STATUS)) or (not pwrite and off == TXDATA)
        if (p == 'ro_write' and pwrite and off == STATUS) or (p == 'wo_read' and not pwrite and off == TXDATA):
            err = False
        access = psel and penable
        pready = not (p == 'stall' and access and pwrite and off == TXDATA and tx_full and not self.stalled)
        self.stalled = not pready
        done = access and pready
        pslverr = done and err
        if done and ((p == 'err_full' and pwrite and off == TXDATA and tx_full)
                     or (p == 'err_rxread' and not pwrite and off == RXDATA)
                     or (p == 'err_ctrl' and pwrite and off == CTRL)):
            pslverr = True
        if p == 'err_idle' and psel and not penable:
            pslverr = True
        prdata, pop_rx, push_tx, set_ovf = 0, False, False, False
        if done and not pwrite:
            if err:
                prdata = 0xEE if p == 'err_data' else 0
            elif off == RXDATA:
                if not rx_empty:
                    prdata, pop_rx = self.mem[self.rd % DEPTH] ^ (p == 'head_wrong'), True
                elif p == 'pop_ungated':
                    pop_rx = True
                elif p == 'stale_read':
                    prdata = self.last_pop
            elif off == STATUS:
                prdata = (len(self.tx) == 0) | (tx_full << 1) | (rx_empty << 2) | ((self.rx_level() == DEPTH) << 3)
                pop_rx = p == 'status_pop' and not rx_empty
            elif off in self.regs:
                prdata = self.regs[off]
        setup = psel and not penable
        if p == 'double_pop' and setup and not pwrite and off == RXDATA and not rx_empty:
            pop_rx = True
        if p == 'setup_push' and setup and pwrite and off == TXDATA and not tx_full:
            push_tx = True
        if p == 'setup_ctrl' and setup and pwrite and off == CTRL:
            self.regs[CTRL] = pwdata
        if p == 'idle_ovf' and not psel and tx_full:
            set_ovf = True
        if done and pwrite and not err:
            if off == TXDATA:
                if not tx_full or (p == 'accept_pop' and shifter_pop):
                    push_tx = True
                    set_ovf = p == 'ovf_always'
                else:
                    set_ovf = p != 'no_ovf'
                    if p == 'push_full':
                        self.tx[-1] = pwdata & 0xFF
            elif off == INT_STATUS:
                if p == 'w1c_zero':
                    self.regs[INT_STATUS] = 0
                elif p != 'w1c_dead':
                    self.regs[INT_STATUS] &= ~pwdata
            else:
                self.regs[off] = pwdata
                push_tx = p == 'ctrl_push' and off == CTRL and not tx_full
        if (p == 'err_side' and pslverr and pwrite and off == RXDATA) or \
           (p == 'ovf_nodecode' and done and pwrite and paddr < 4 and tx_full):
            set_ovf = True
        # clock edge: the APB access has read the flags above; then the shifter and the receiver act
        if pop_rx:
            self.last_pop = self.mem[self.rd % DEPTH]
            self.rd = (self.rd + 1) % (2 * DEPTH)
        if shifter_pop and self.tx:
            self.tx.pop(0)
        if push_tx:
            self.tx.append((pwdata & 0xFF) ^ (p == 'push_corrupt'))
        if rx_push is not None and self.rx_level() < DEPTH:
            self.mem[self.wr % DEPTH] = rx_push
            self.wr = (self.wr + 1) % (2 * DEPTH)
        if set_ovf:
            self.regs[INT_STATUS] |= TX_OVF
        return pready, pslverr, prdata


def observe(s):
    return list(s.tx), s.rx_list(), dict(s.regs)


class Checker:
    """Predicts the next state of every cycle from pins and observations; reports under row IDs."""
    def __init__(self):
        self.fails = []
        self.cov = dict.fromkeys(('tx full write', 'write on a shifter pop, tx full', 'errored write, tx full',
                                  'empty read with push', 'w1c clear of a set TX_OVF',
                                  'w1c write of 0, TX_OVF set'), 0)

    def fail(self, req, msg):
        self.fails.append(f'{req}: {msg}')

    def check(self, pins, out, before, after, shifter_pop, rx_push):
        psel, penable, pwrite, paddr, pwdata = pins
        pready, pslverr, prdata = out
        tx0, rx0, r0 = before
        tx1, rx1, r1 = after
        exp_tx = tx0[1:] if shifter_pop and tx0 else list(tx0)        # what the shifter and receiver do
        exp_rx = [rx0 + [rx_push] if rx_push is not None and len(rx0) < DEPTH else list(rx0)]
        exp_r = dict(r0)
        access = psel and penable
        if access and not pready:
            self.fail('REQ-IF-001', f'PREADY low in an Access cycle at 0x{paddr:X}')
        if pslverr and not (access and pready):
            self.fail('REQ-IF-010', 'PSLVERR high outside the last cycle of a transfer')
        n0 = len(self.fails)
        own = 'REQ-IF-012'                 # a cycle that completes no transfer: no APB side effect at all
        if access and pready:
            unmapped = paddr not in REGS
            ro_write = pwrite and paddr in (RXDATA, STATUS)
            wo_read = not pwrite and paddr == TXDATA
            expect_err = unmapped or ro_write or wo_read
            if pwrite and expect_err and len(tx0) == DEPTH:
                self.cov['errored write, tx full'] += 1
            if unmapped and not pslverr:
                self.fail('REQ-ERR-004', f'no PSLVERR at unmapped offset 0x{paddr:X}')
            if ro_write and not pslverr:
                self.fail('REQ-ERR-005', f'no PSLVERR on a write to read-only 0x{paddr:X}')
            if wo_read and not pslverr:
                self.fail('REQ-ERR-006', 'no PSLVERR on a read of write-only TXDATA')
            if pslverr and not pwrite and prdata != 0:
                self.fail('REQ-IF-008', f'errored read at 0x{paddr:X} returned 0x{prdata:X}')
            if expect_err:
                own = 'REQ-ERR-007'
            else:
                own = 'REQ-IF-011'
                if pslverr:
                    row = 'REQ-IF-002' if pwrite and paddr == TXDATA else \
                          'REQ-IF-004' if not pwrite and paddr == RXDATA else 'REQ-IF-009'
                    self.fail(row, f'PSLVERR on a legal access at 0x{paddr:X}')
                if pwrite and paddr == TXDATA:
                    if len(tx0) == DEPTH:
                        self.cov['tx full write'] += 1
                        self.cov['write on a shifter pop, tx full'] += shifter_pop
                        if tx1 != exp_tx:
                            self.fail('REQ-ERR-001', 'a TXDATA write to a full TX FIFO changed the FIFO')
                        if not r1[INT_STATUS] & TX_OVF:
                            self.fail('REQ-ERR-002', 'TX_OVF not set by a TXDATA write to a full TX FIFO')
                        exp_r[INT_STATUS] |= TX_OVF
                    else:
                        exp_tx = exp_tx + [pwdata & 0xFF]
                        if tx1 != exp_tx:
                            self.fail('REQ-IF-007', 'a TXDATA write with room did not push exactly PWDATA[7:0]')
                elif not pwrite and paddr == RXDATA:
                    if not rx0:
                        self.cov['empty read with push'] += rx_push is not None
                        if prdata != 0:
                            self.fail('REQ-IF-003', f'empty RXDATA read returned 0x{prdata:X}')
                        if rx1 not in exp_rx:
                            self.fail('REQ-ERR-003', 'an empty RXDATA read left the RX FIFO other than the receiver leaves it')
                    else:
                        if prdata & 0xFF != rx0[0]:
                            self.fail('REQ-IF-005', f'RXDATA read returned 0x{prdata:X}, head 0x{rx0[0]:X}')
                        exp_rx = [rx0[1:] + ([rx_push] if rx_push is not None and len(rx0) < DEPTH else [])]
                        if rx_push is not None and len(rx0) == DEPTH:      # pop and push on a full RX FIFO:
                            exp_rx.append(rx0[1:] + [rx_push])           # overrun policy open (OI-04)
                        if rx1 not in exp_rx:
                            self.fail('REQ-IF-006', 'a RXDATA read with data did not pop exactly one entry')
                elif pwrite and paddr == INT_STATUS:
                    if r0[INT_STATUS] & TX_OVF:
                        self.cov['w1c clear of a set TX_OVF' if pwdata & TX_OVF else 'w1c write of 0, TX_OVF set'] += 1
                    exp_r[INT_STATUS] = r0[INT_STATUS] & ~pwdata
                    if r1[INT_STATUS] != exp_r[INT_STATUS]:
                        self.fail('REQ-FUNC-001', f'INT_STATUS 0x{r0[INT_STATUS]:X}, write 0x{pwdata:X}, gave 0x{r1[INT_STATUS]:X}')
                elif pwrite:                                               # CTRL, BAUDDIV, INT_EN
                    exp_r[paddr] = r1[paddr]                               # the stored value: OI-06 (Gate 3)
        # every cycle: nothing changes but what the shifter, the receiver and the row named above change
        if (tx1 != exp_tx or rx1 not in exp_rx or r1 != exp_r) and len(self.fails) == n0:   # only if no row
            self.fail(own, f'state changed beyond its row at 0x{paddr:X}')                 # failed already


def transfer(s, c, pwrite, paddr, pwdata=0, sp=(False, False), rp=(None, None)):
    """One APB transfer: Setup, then Access cycles until PREADY (at most 4)."""
    for i, pen in enumerate([False, True, True, True, True]):
        pins = (True, pen, pwrite, paddr, pwdata)
        k = min(i, 1)
        before = observe(s)
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


def run(plant, seed=1):
    s, c = Slave(plant), Checker()
    # directed cases
    for b in range(DEPTH + 2):                           # fill, then two writes to a full TX FIFO
        transfer(s, c, True, TXDATA, 0x30 + b)
    transfer(s, c, True, TXDATA, 0x77, sp=(False, True))  # write in the cycle of a shifter pop, FIFO full (D-029)
    transfer(s, c, True, TXDATA, 0x78)                   # refill
    transfer(s, c, True, INT_STATUS, 0)                  # W1C: a write of 0 leaves TX_OVF set
    transfer(s, c, True, INT_STATUS, TX_OVF)             # W1C: a write of 1 clears it
    for off in (0x01, 0x02, 0x03, RXDATA, STATUS, 0x1C, 0xFFC):   # errored writes with the TX FIFO full
        transfer(s, c, True, off, 0xA5)
    transfer(s, c, False, TXDATA)                        # write-only read (D-030)
    for _ in range(DEPTH + 1):
        idle(s, c, sp=True)
    transfer(s, c, False, RXDATA)                        # empty read
    transfer(s, c, False, RXDATA, rp=(None, 0x41))       # empty read in the cycle of a receiver push
    transfer(s, c, False, RXDATA)                        # that byte, read next
    for v in (0x11, 0x22):
        idle(s, c, rp=v)
    transfer(s, c, False, RXDATA)
    transfer(s, c, False, STATUS)
    transfer(s, c, True, CTRL, 0x3)
    for off in range(WINDOW):                            # window sweep: every byte offset with no register
        if off not in REGS:
            transfer(s, c, False, off)
            transfer(s, c, True, off, 0xA5)
    # random cases, in blocks that alternate a slow and a busy shifter so both FIFOs reach full and empty
    rnd = random.Random(seed)
    offs = [TXDATA, TXDATA, RXDATA, STATUS, CTRL, BAUDDIV, INT_EN, INT_STATUS, 0x1C, 0x02, 0x104, 0xFFC]
    for block in range(8):
        p_pop = 0.4 if block % 2 else 0.02
        for _ in range(600):
            if rnd.random() < 0.3:
                idle(s, c, rnd.random() < p_pop, rnd.randrange(256) if rnd.random() < 0.3 else None)
            else:
                sp = (rnd.random() < p_pop, rnd.random() < p_pop)
                rp = tuple(rnd.randrange(256) if rnd.random() < 0.2 else None for _ in range(2))
                transfer(s, c, rnd.random() < 0.5, rnd.choice(offs), rnd.randrange(256), sp, rp)
    return c


def never_run(cov):
    return [k for k, v in cov.items() if not v]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--plant', choices=sorted(PLANTS))
    a = ap.parse_args()
    names = [a.plant] if a.plant else sorted(PLANTS, key=lambda n: (PLANTS[n][0], n))
    bad = False
    if not a.plant:
        c = run(None)
        zero = never_run(c.cov)
        print(f'{"PASS" if not (c.fails or zero) else "FAIL"}    correct model: {len(c.fails)} assertion failures, '
              f'{len(zero)} corner cases never run')
        for f in c.fails[:3]:
            print(f'        {f}')
        print('        coverage: ' + ', '.join(f'{k} {v}' for k, v in c.cov.items()))
        if zero:
            print(f'        never run: {", ".join(zero)}')
        planted = never_run(dict(c.cov, **{next(iter(c.cov)): 0}))      # the coverage rule, seen failing
        print(f'{"PASS" if planted else "FAIL"}    a zero coverage count fails the run (planted: {planted})')
        bad = bool(c.fails or zero or not planted)
    caught = 0
    for name in names:
        row, text = PLANTS[name]
        fails = run(name).fails
        hit = bool(fails) and fails[0].startswith(row + ':')           # reported first under its own row
        caught += hit
        print(f'{"CAUGHT" if hit else "MISSED"}  {name} ({row}): {text}' +
              ('' if hit else f'\n        reported: {fails[0] if fails else "nothing"}'))
    print(f'apb_slave_model: correct model {"FAILS" if bad else "passes"}; '
          f'{caught} of {len(names)} planted bugs caught under the row they break')
    return 0 if not bad and caught == len(names) else 1


if __name__ == '__main__':
    sys.exit(main())
