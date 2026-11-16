// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
//
// p18 anti-vacuity: a[0] is left out of the reduction, so this is NOT equivalent.
module p18_par (input logic [7:0] d, input logic odd, output logic p);
  logic [3:0] a;
  assign a = d[7:4] ^ d[3:0];
  assign p = ^{a[3:1], odd};
endmodule
