// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 murugan-15
//
// p23 anti-vacuity: three rule violations svlint must report:
//   no `default_nettype none; a blocking assignment in always_ff; a plain always.
module p23_twin (input logic clk, input logic a, output logic q, output logic r);
  always_ff @(posedge clk) q = a;
  always @(posedge clk) r <= a;
endmodule
