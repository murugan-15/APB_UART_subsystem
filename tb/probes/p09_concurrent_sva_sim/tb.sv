// p09: concurrent SVA in simulation (dual property).
// ack is req delayed by exactly one cycle, so
//   a_good: req |-> ##1 ack  never fails, and
//   a_bad:  req |-> ##2 ack  fails once per req pulse (3 pulses -> 3 fails).
// A tool that parses but ignores concurrent assertions shows 0 failures for
// both; only the a_bad count tells "assertion holds" apart from
// "assertion never evaluated".
module p09_tb;
  logic clk = 1'b0, req = 1'b0, ack = 1'b0;
  int   fail_good = 0, fail_bad = 0;

  always #5 clk = ~clk;
  always @(posedge clk) ack <= req;

  a_good: assert property (@(posedge clk) req |-> ##1 ack) else fail_good++;
  a_bad:  assert property (@(posedge clk) req |-> ##2 ack) else fail_bad++;

  initial begin
    repeat (2) @(negedge clk);
    repeat (3) begin
      req = 1'b1;
      @(negedge clk) req = 1'b0;
      repeat (3) @(negedge clk);
    end
    repeat (4) @(negedge clk);
    if (fail_good == 0 && fail_bad == 3) $display("PROBE_PASS");
    else $display("PROBE_FAIL fail_good=%0d fail_bad=%0d", fail_good, fail_bad);
    $finish;
  end
endmodule
