// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
//
// p19 testbench (plain Verilog: mcy runs it under Icarus on the mutated netlist).
//   -DWEAK  drives the same stimulus but checks nothing
module p19_tb;
  reg clk, rst_n; reg [3:0] a, b; wire [4:0] sum; wire par;
  integer i, errors;
  p19_dut dut (.clk(clk), .rst_n(rst_n), .a(a), .b(b), .sum(sum), .par(par));
  initial begin clk = 1'b0; rst_n = 1'b0; a = 4'd0; b = 4'd0; errors = 0; end
  always #5 clk = ~clk;
  initial begin
    repeat (2) @(negedge clk);
`ifndef WEAK
    if (sum !== 5'd0 || par !== 1'b0) errors = errors + 1;       // reset values
`endif
    rst_n = 1'b1;
    for (i = 0; i < 256; i = i + 1) begin
      a = i[3:0]; b = i[7:4];
      @(negedge clk);                                             // check at the opposite edge
`ifndef WEAK
      if (sum !== a + b || par !== ^{a, b}) errors = errors + 1;
`endif
    end
    if (errors == 0) $display("PASS"); else $display("ERROR %0d mismatches", errors);
    $finish;
  end
endmodule
