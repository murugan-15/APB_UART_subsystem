// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
//
// p22: slang as a second SystemVerilog front end (scripts/slang_check.py).
// This file is legal and must compile without an error.
module p22_good (input logic clk, input logic [3:0] a, output logic [3:0] y);
  logic [3:0] q;
  always_ff @(posedge clk) q <= a;
  assign y = q;
endmodule
