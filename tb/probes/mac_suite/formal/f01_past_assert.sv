// Probe F01 — the formal style of conventions.md §5 on open-source Yosys + sby:
// immediate assert/assume/cover in clocked blocks, $past with an f_past_valid guard,
// and the ASSUME macro acting as an environment constraint.
//
// DUT: mod-10 counter with synchronous load. Invariant cnt_q <= 9 holds ONLY if the
// environment never loads a value > 9, so the ASSUME is load-bearing.
//
// Variants (selected by the .sby task):
//   default           -> all properties hold                     (expect PASS)
//   PROBE_BUG         -> adds a false assertion cnt_q <= 8       (expect FAIL)
//   PROBE_NO_ASSUME   -> drops the ld_val constraint             (expect FAIL)

`default_nettype none
`include "probe_assume.svh"

module f01_past_assert (
  input  wire logic       clk,
  input  wire logic       rst_n,
  input  wire logic       en,
  input  wire logic       load,
  input  wire logic [3:0] ld_val,
  output      logic [3:0] cnt_q
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)              cnt_q <= 4'd0;
    else if (load)           cnt_q <= ld_val;
    else if (en)             cnt_q <= (cnt_q == 4'd9) ? 4'd0 : cnt_q + 4'd1;
  end

`ifdef FORMAL
  logic f_past_valid = 1'b0;
  always @(posedge clk) f_past_valid <= 1'b1;

  // Start in reset.
  always @(*) if (!f_past_valid) assume (!rst_n);

  // Environment constraint.
`ifndef PROBE_NO_ASSUME
  always @(*) if (load) `ASSUME (ld_val <= 4'd9);
`endif

  always @(posedge clk) begin
    a_range: assert (cnt_q <= 4'd9);

    if (f_past_valid && $past(rst_n) && rst_n && !$past(load)) begin
      if ($past(en)) a_step: assert (cnt_q == (($past(cnt_q) == 4'd9) ? 4'd0 : $past(cnt_q) + 4'd1));
      else           a_hold: assert (cnt_q == $past(cnt_q));
    end

`ifdef PROBE_BUG
    a_bug: assert (cnt_q <= 4'd8);
`endif

    c_wrap: cover (f_past_valid && $past(cnt_q) == 4'd9 && cnt_q == 4'd0);
  end
`endif

endmodule

`default_nettype wire
