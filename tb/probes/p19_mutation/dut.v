// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 murugan-15
//
// p19: mutation coverage with mcy. Yosys plants one small change (a mutation)
// at a time in this module; a testbench that checks the outputs must fail on
// most of them (COVERED). The same run with a testbench that checks nothing
// must cover none: that is the anti-vacuity run.
module p19_dut (input clk, input rst_n, input [3:0] a, input [3:0] b, output reg [4:0] sum, output reg par);
  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      sum <= 5'd0;
      par <= 1'b0;
    end else begin
      sum <= a + b;
      par <= ^{a, b};
    end
endmodule
