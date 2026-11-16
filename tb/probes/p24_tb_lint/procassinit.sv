// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
//
// p24: a declaration initializer on a variable that a process also assigns.
// It is accepted by default and rejected under -Wall (PROCASSINIT): the basis
// of conventions rule 19, D-016 (on for rtl/, waived for testbenches).
module p24_procassinit (input logic clk, input logic d, output logic q);
  logic q_q = 1'b0;
  always_ff @(posedge clk) q_q <= d;
  assign q = q_q;
endmodule
