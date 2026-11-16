// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
//
// p24: the lint warnings that conventions rule 7 relies on really fire.
// A variable declared inside a procedural block with an initializer is static:
// the initializer runs once, not on every pass of the loop (IEEE 1800-2023
// 6.21). Verilator must reject this file with IMPLICITSTATIC.
module p24_static_init;
  int total;
  initial begin
    total = 0;
    for (int k = 0; k < 3; k++) begin
      int n = 0;                 // set once only: n keeps counting across passes
      n += 1;
      total += n;
    end
    $display("total=%0d", total);
    $finish;
  end
endmodule
