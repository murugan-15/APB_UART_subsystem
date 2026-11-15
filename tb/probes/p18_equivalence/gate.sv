// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 murugan-15
//
// p18: the same function, restructured as a two-level XOR tree.
module p18_par (input logic [7:0] d, input logic odd, output logic p);
  logic [3:0] a;
  assign a = d[7:4] ^ d[3:0];
  assign p = ^{a, odd};
endmodule
