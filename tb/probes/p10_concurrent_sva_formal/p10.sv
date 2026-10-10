// p10: concurrent SVA under Yosys/sby (dual property, same pair as p09).
// good must PASS and bad must FAIL. If Yosys rejects the syntax both tasks
// error out; if it silently drops the assertion both PASS. Either way the
// check fails, which is the point.
module p10 (input logic clk, input logic req, output logic ack);
  initial ack = 1'b0;
  always_ff @(posedge clk) ack <= req;

`ifdef FORMAL
`ifdef BAD
  a_p: assert property (@(posedge clk) req |-> ##2 ack);
`else
  a_p: assert property (@(posedge clk) req |-> ##1 ack);
`endif
`endif
endmodule
