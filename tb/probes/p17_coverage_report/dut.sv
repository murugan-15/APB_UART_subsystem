// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
//
// p17: code coverage that can be read. Verilator --coverage writes
// coverage.dat; verilator_coverage converts it to lcov format; genhtml makes
// an HTML report. The branch on sel == 2'd3 is never taken by the testbench:
// the report must show that line with a count of 0 (anti-vacuity).
module p17_dut (input logic clk, input logic rst_n, input logic [1:0] sel, output logic [3:0] q);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) q <= '0;
    else if (sel == 2'd3)
      q <= 4'hF;
    else
      q <= q + 4'd1;
endmodule
