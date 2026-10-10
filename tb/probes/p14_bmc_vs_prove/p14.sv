// p14: what a BMC "PASS" does and does not mean.
//   deep    : free-running 5-bit counter, bug state cnt == 30 is reachable
//             only at step 30. BMC depth 24 must PASS (it never looks that
//             deep); PDR (unbounded) must FAIL.
//   good    : counter wraps at 20, assert cnt <= 20 -> PDR must PROVE it.
// Only an unbounded proof covers all reachable states.
module p14 (input logic clk, output logic [4:0] cnt);
  initial cnt = '0;

`ifdef GOOD
  always_ff @(posedge clk) cnt <= (cnt == 5'd20) ? 5'd0 : cnt + 5'd1;
`else
  always_ff @(posedge clk) cnt <= cnt + 5'd1;
`endif

`ifdef FORMAL
`ifdef GOOD
  always @(*) assert (cnt <= 5'd20);
`else
  always @(*) assert (cnt != 5'd30);
`endif
`endif
endmodule
