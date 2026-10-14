// Probe F03 — `bind` under open-source Yosys: attach a property module to a DUT's
// internal signal without editing the DUT.
//   default    -> checker asserts cnt <= 9 (true)     (expect PASS)
//   PROBE_BUG  -> checker asserts cnt <= 8 (false)    (expect FAIL; proves the bound
//                 checker was really elaborated and not silently dropped)

`default_nettype none

module f03_dut (
  input wire logic clk,
  input wire logic rst_n,
  input wire logic en
);
  logic [3:0] cnt_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)  cnt_q <= 4'd0;
    else if (en) cnt_q <= (cnt_q == 4'd9) ? 4'd0 : cnt_q + 4'd1;
  end
endmodule

module f03_checker (
  input wire logic       clk,
  input wire logic       rst_n,
  input wire logic [3:0] cnt
);
`ifdef FORMAL
  logic f_past_valid = 1'b0;
  always @(posedge clk) f_past_valid <= 1'b1;
  always @(*) if (!f_past_valid) assume (!rst_n);

  always @(posedge clk) begin
`ifdef PROBE_BUG
    a_bug: assert (cnt <= 4'd8);
`else
    a_range: assert (cnt <= 4'd9);
`endif
  end
`endif
endmodule

bind f03_dut f03_checker u_chk (.clk(clk), .rst_n(rst_n), .cnt(cnt_q));

`default_nettype wire
