// p12: `bind` of a checker module into a DUT, the planned way to attach
// SVA to RTL without editing it.
// The checker holds a good check (y == previous a, must never fire) and a
// bad check (y == a, must fire). If a tool silently drops the bind, the bad
// check never runs, so the dual check catches it.
module p12_dut (input logic clk, input logic a, output logic y);
  always_ff @(posedge clk) y <= a;
endmodule

module p12_chk (input logic clk, input logic a, input logic y);
  logic past_valid = 1'b0;
  logic a_q;
  always @(posedge clk) begin
    past_valid <= 1'b1;
    a_q        <= a;
  end

`ifdef FORMAL
  always @(posedge clk)
    if (past_valid) begin
      assert (y == a_q);
`ifdef BAD
      assert (y == a);
`endif
    end
`else
  int fired_good = 0, fired_bad = 0;
  always @(posedge clk)
    if (past_valid) begin
      a_good: assert (y == a_q) else fired_good++;
      a_bad:  assert (y == a)   else fired_bad++;
    end
`endif
endmodule
