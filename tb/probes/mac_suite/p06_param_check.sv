// Probe P06 (TB side) — instantiates p06_param_stub with DEPTH = `P06_DEPTH.
// Two runs per tool (driven by scripts/probe.sh):
//   positive: P06_DEPTH=4 -> must elaborate and print PROBE PASS
//   negative: P06_DEPTH=3 -> must FAIL to elaborate (that failure is the pass condition)

`ifndef P06_DEPTH
  `define P06_DEPTH 4
`endif

module p06_param_check;
  logic clk = 1'b0;
  logic [$clog2(`P06_DEPTH)-1:0] addr;

  p06_param_stub #(.DEPTH(`P06_DEPTH)) u_stub (.clk(clk), .addr_q(addr));

  initial begin
    $display("PROBE PASS: p06_param_check elaborated with DEPTH=%0d", `P06_DEPTH);
    $finish;
  end
endmodule
