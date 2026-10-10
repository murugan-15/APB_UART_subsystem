// p08: elaboration-time parameter check with $error in a generate block.
// This is how the UART will reject illegal parameters (e.g. FIFO depth not a
// power of two). Dual check: the legal top must elaborate cleanly AND the
// illegal top must be rejected with our message.
module p08_dut #(parameter int W = 8) (
  input  logic [W-1:0] a,
  output logic [W-1:0] y
);
  // Convention: a single string literal. Icarus 13 rejects elaboration
  // tasks with format arguments ("sorry: ... single string argument"),
  // which the -DFMT_ARGS check pins down.
  if (W < 2) begin : g_param_check
`ifdef FMT_ARGS
    $error("p08_dut: W must be >= 2, got %0d", W);
`else
    $error("p08_dut: W must be >= 2");
`endif
  end
  assign y = ~a;
endmodule

module p08_top_good (input logic [7:0] a, output logic [7:0] y);
  p08_dut #(.W(8)) u (.a(a), .y(y));
endmodule

module p08_top_bad (input logic [0:0] a, output logic [0:0] y);
  p08_dut #(.W(1)) u (.a(a), .y(y));
endmodule
