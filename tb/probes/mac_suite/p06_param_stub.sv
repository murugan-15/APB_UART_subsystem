// Probe P06 (DUT side) — elaboration-time parameter validation with $error in a generate block.
// Synthesizable on purpose: Yosys must reject an illegal DEPTH too, not only simulators.
// Rule under test: DEPTH must be a power of two and >= 2.

`default_nettype none

module p06_param_stub #(
  parameter int DEPTH = 4
) (
  input  wire logic                       clk,
  output      logic [$clog2(DEPTH)-1:0]   addr_q
);

  if (DEPTH < 2 || (DEPTH & (DEPTH - 1)) != 0) begin : g_bad_depth
    // Single string argument only: Icarus 13 rejects elaboration tasks with format args.
    $error("p06_param_stub: DEPTH must be a power of two >= 2");
  end

  always_ff @(posedge clk) addr_q <= addr_q + 1'b1;

endmodule

`default_nettype wire
