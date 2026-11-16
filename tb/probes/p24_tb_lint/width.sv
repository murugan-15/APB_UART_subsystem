// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
//
// p24: an implicit width extension. Verilator must reject this file with a
// WIDTH warning; rule 7 asks for an explicit cast instead.
module p24_width (input logic [3:0] a, output logic [7:0] b);
  assign b = a + 4'd1;
endmodule
