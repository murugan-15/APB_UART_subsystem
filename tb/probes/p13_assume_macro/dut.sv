// p13: the ASSUME macro convention.
// An input requirement the DUT relies on is written once as `ASSUME:
//   formal -> assume : the solver only explores legal inputs
//   sim    -> assert : the integrator's testbench / SoC is checked against it
// This makes the requirement the integrator's job to meet, and every
// simulation checks that they do.
`ifdef FORMAL
  `define ASSUME(expr) assume (expr)
`else
  `define ASSUME(expr) assert (expr)
`endif

module p13_dut (
  input  logic       clk,
  input  logic       rst,
  input  logic       start,
  input  logic [3:0] len,
  output logic       busy
);
  logic [3:0] cnt;

  always_ff @(posedge clk)
    if (rst) begin
      busy <= 1'b0;
      cnt  <= '0;
    end else if (start && !busy) begin
      busy <= 1'b1;
      cnt  <= len;
    end else if (busy) begin
      cnt <= cnt - 4'd1;
      if (cnt == 4'd1) busy <= 1'b0;
    end

  // Integrator obligation: never start a transfer of length 0.
`ifndef NO_ASSUME
  always @(*) if (start && !rst) `ASSUME(len != 4'd0);
`endif

`ifdef FORMAL
  logic f_past_valid = 1'b0;
  always @(posedge clk) f_past_valid <= 1'b1;
  always @(*) if (!f_past_valid) assume (rst);
  // Holds only if the obligation above is met.
  always @(*) if (busy) assert (cnt != 4'd0);
`endif
endmodule
