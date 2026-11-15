// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 murugan-15
//
// p22 anti-vacuity: q is written by an always_ff and by an always_comb, which
// IEEE 1800 forbids. slang must report an error. (Icarus 13.0 accepts it.)
module p22_bad (input logic clk, input logic [3:0] a, output logic [3:0] y);
  logic [3:0] q;
  always_ff @(posedge clk) q <= a;
  always_comb q = ~a;
  assign y = q;
endmodule
