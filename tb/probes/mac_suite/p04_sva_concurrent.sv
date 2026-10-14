// Probe P04 — concurrent SVA in simulation: assert property, |->, ##N, disable iff, $rose.
// Needed for: simulation assertions in assertions/.
// Self-checking: a property that holds must never fire, AND a deliberately false property
// must fire. A simulator that silently ignores concurrent assertions fails the second check.

module p04_sva_concurrent;

  logic clk   = 1'b0;
  logic rst_n = 1'b0;
  logic req   = 1'b0;
  logic ack   = 1'b0;
  int   good_fails = 0;
  int   bad_fails  = 0;

  always #5 clk = ~clk;

  // "DUT": ack is req registered on the clock edge, so ack follows req by exactly one cycle.
  // (Driving ack on the same negedge as the stimulus would race with the req update.)
  always @(posedge clk) ack <= req;

  // Holds by construction.
  a_good: assert property (@(posedge clk) disable iff (!rst_n) $rose(req) |-> ##1 ack)
          else good_fails++;

  // Deliberately false: ack is high one cycle after req, never required two cycles after
  // a single-cycle req pulse.
  a_bad:  assert property (@(posedge clk) disable iff (!rst_n) $rose(req) |-> ##2 ack)
          else bad_fails++;

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(negedge clk);
    for (int i = 0; i < 3; i++) begin      // three single-cycle req pulses, spaced apart
      req = 1'b1; @(negedge clk);
      req = 1'b0; repeat (4) @(negedge clk);
    end
    repeat (4) @(negedge clk);

    $display("INFO: good_fails=%0d bad_fails=%0d", good_fails, bad_fails);
    if (good_fails == 0 && bad_fails > 0) $display("PROBE PASS: p04_sva_concurrent");
    else $fatal(1, "PROBE FAIL: p04_sva_concurrent (good_fails=%0d, bad_fails=%0d; expected 0 and >0)",
                good_fails, bad_fails);
    $finish;
  end

endmodule
