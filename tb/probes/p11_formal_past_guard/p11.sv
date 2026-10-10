// p11: formal-style immediate assertions with $past and the f_past_valid
// guard (the convention used in all of this project's formal properties).
//   good    : correct register, guarded assertion      -> must PASS
//   bad     : register corrupts d == 8'hA5, guarded     -> must FAIL with trace
//   noguard : correct register, UNguarded assertion    -> fails spuriously on
//             its first evaluation (smtbmc reports step 1): a clocked
//             assertion samples pre-edge values, so it compares the
//             uninitialized q with the uninitialized $past(d) register
module p11 (input logic clk, input logic [7:0] d, output logic [7:0] q);
`ifdef BAD
  always_ff @(posedge clk) q <= (d == 8'hA5) ? 8'h00 : d;
`else
  always_ff @(posedge clk) q <= d;
`endif

`ifdef FORMAL
  logic f_past_valid = 1'b0;
  always @(posedge clk) f_past_valid <= 1'b1;

  always @(posedge clk) begin
`ifdef NOGUARD
    assert (q == $past(d));
`else
    if (f_past_valid) assert (q == $past(d));
`endif
  end
`endif
endmodule
