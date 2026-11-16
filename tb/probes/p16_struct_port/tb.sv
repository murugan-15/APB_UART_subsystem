// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
//
// p16 testbench. Reset is released and the result is checked at negedge, so
// sampling at posedge is race-free (p04 / BUG-001).
//   -DTWIN  expects a wrong value: the run must then print PROBE_FAIL
//           (anti-vacuity: the check really compares the struct's data)
module p16_tb;
  logic       clk, rst_n;
  logic [7:0] last;
`ifdef TWIN
  localparam logic [7:0] WANT = 8'd5;
`else
  localparam logic [7:0] WANT = 8'd4;
`endif

  p16_dut dut (.clk(clk), .rst_n(rst_n), .last(last));

  initial begin
    clk   = 1'b0;
    rst_n = 1'b0;
  end
  always #5 clk = ~clk;

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1'b1;
    repeat (5) @(negedge clk);   // after k posedges: o.data == k, last == k-1
    if (last === WANT) $display("PROBE_PASS");
    else               $display("PROBE_FAIL last=%0d", last);
    $finish;
  end
endmodule
