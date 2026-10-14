// Probe F02 — concurrent SVA (assert property, |->, ##N, disable iff) in open-source Yosys.
// conventions.md §5 treats this as unsupported in formal until this probe says otherwise.
//   default    -> req |-> ##1 ack_q  holds          (expect PASS)
//   PROBE_BUG  -> req |-> ##2 ack_q  is false       (expect FAIL; proves it is not ignored)

`default_nettype none

module f02_sva_concurrent (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic req,
  output      logic ack_q
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) ack_q <= 1'b0;
    else        ack_q <= req;
  end

`ifdef FORMAL
  logic f_past_valid = 1'b0;
  always @(posedge clk) f_past_valid <= 1'b1;
  always @(*) if (!f_past_valid) assume (!rst_n);

`ifdef PROBE_BUG
  a_seq: assert property (@(posedge clk) disable iff (!rst_n) req |-> ##2 ack_q);
`else
  a_seq: assert property (@(posedge clk) disable iff (!rst_n) req |-> ##1 ack_q);
`endif
`endif

endmodule

`default_nettype wire
