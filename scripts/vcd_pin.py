#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
"""vcd_pin.py: copy one 1-bit signal of a VCD into a minimal VCD (timescale 1 ns).

sigrok-cli's VCD reader wants a small, single-bit dump; a simulator's dump holds every signal,
often in picoseconds. The last line written is the end time of the simulation, so a decoder still
has samples after the final edge (the last stop bit).

  scripts/vcd_pin.py <in.vcd> <scope> <signal> <out.vcd>
"""
import re
import sys

UNIT_NS = {'s': 1e9, 'ms': 1e6, 'us': 1e3, 'ns': 1.0, 'ps': 1e-3, 'fs': 1e-6}


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    src, scope, name, out = argv
    ident, path, t_ns, last, lines, scale = None, [], 0, None, [], None
    text = open(src, encoding='utf-8', errors='replace').read()
    m = re.search(r'\$timescale\s+(\d+)\s*(s|ms|us|ns|ps|fs)\s+\$end', text)
    if not m:
        print('vcd_pin: no $timescale in', src)
        return 1
    scale = int(m.group(1)) * UNIT_NS[m.group(2)]
    for ln in text.splitlines():
        w = ln.split()
        if not w:
            continue
        if w[0] == '$scope':
            path.append(w[2])
        elif w[0] == '$upscope':
            path.pop()
        elif w[0] == '$var' and path and path[-1] == scope and w[4] == name and w[2] == '1' and ident is None:
            ident = w[3]
        elif w[0].startswith('#') and w[0][1:].isdigit():
            t_ns = round(int(w[0][1:]) * scale)
        elif ident and w[0][0] in '01xzXZ' and w[0][1:] == ident and w[0][0] != last:
            last = w[0][0]
            lines.append(f'#{t_ns}\n{last}!\n')
    if ident is None:
        print(f'vcd_pin: no 1-bit signal {scope}.{name} in {src}')
        return 1
    with open(out, 'w', encoding='utf-8') as f:
        f.write(f'$timescale 1ns $end\n$scope module top $end\n$var wire 1 ! {name} $end\n'
                '$upscope $end\n$enddefinitions $end\n')
        f.writelines(lines)
        f.write(f'#{t_ns}\n')
    print(f'{scope}.{name}: {len(lines)} changes, end at {t_ns} ns')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
