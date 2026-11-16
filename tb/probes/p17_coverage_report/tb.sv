// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
//
// p17 testbench: drives sel through 0, 1, 2 only.
module p17_tb;
  logic clk, rst_n; logic [1:0] sel; logic [3:0] q;
  p17_dut dut (.clk(clk), .rst_n(rst_n), .sel(sel), .q(q));
  initial begin clk = 1'b0; rst_n = 1'b0; sel = 2'd0; end
  always #5 clk = ~clk;
  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1'b1;
    for (int i = 0; i < 6; i++) begin
      sel = 2'(i % 3);
      @(negedge clk);
    end
    if (q === 4'd6) $display("PROBE_PASS");
    else            $display("PROBE_FAIL q=%0d", q);
    $finish;
  end
endmodule
