// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 murugan-15
//
// p18: equivalence checking with eqy. gold and gate must be proved equal;
// gold and bad (one input bit dropped) must be reported as different.
module p18_par (input logic [7:0] d, input logic odd, output logic p);
  assign p = (^d) ^ odd;
endmodule
