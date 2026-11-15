#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 murugan-15
"""slang_check.py: compile SystemVerilog with slang, a second front end (D-013).

Runs the full compilation and analysis that the slang command-line tool runs, through pyslang.
The analysis pass matters: without it a variable driven by two processes is not reported
(probe p22 keeps a file that must fail).

  scripts/slang_check.py [slang options] file.sv ...   exit 0: no error; 1: errors; 2: bad usage
"""
import sys

from pyslang import driver


def main(argv):
    d = driver.Driver()
    d.addStandardArgs()
    if not d.parseCommandLine('slang ' + ' '.join(argv), driver.CommandLineOptions()) or not d.processOptions():
        return 2
    ok = d.parseAllSources()
    ok = d.runFullCompilation(False) and ok
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
