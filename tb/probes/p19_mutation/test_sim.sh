#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 murugan-15
#
# mcy test: simulate the mutated module with the p19 testbench.
# P19_DEFS is "-DWEAK" for the anti-vacuity run.
exec 2>&1
set -ex
bash "$SCRIPTS/create_mutated.sh"
# shellcheck disable=SC2086  # P19_DEFS is empty or one -D flag
iverilog ${P19_DEFS:-} -o sim ../../tb.v mutated.v
vvp -n sim >sim.out
if grep -q PASS sim.out && ! grep -q ERROR sim.out; then
  echo "1 PASS" >output.txt
else
  echo "1 FAIL" >output.txt
fi
exit 0
