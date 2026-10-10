// p07a: immediate assertions with action blocks (dual property).
// a_good must never fire; a_bad must fire exactly twice. If a tool silently
// ignored assertions, a_good would "pass" too, but a_bad's count catches it.
module p07_tb_actions;
  int         fired_good = 0, fired_bad = 0, passed_good = 0;
  logic [3:0] x;

  initial begin
    for (int i = 0; i < 4; i++) begin
      x = 4'(i);
      #1;
      a_good: assert (x < 4) passed_good++; else fired_good++;
      a_bad:  assert (x[0] == 1'b0)         else fired_bad++;   // fails for x=1,3
    end
    if (fired_good == 0 && passed_good == 4 && fired_bad == 2) $display("PROBE_PASS");
    else $display("PROBE_FAIL good=%0d/%0d bad=%0d", passed_good, fired_good, fired_bad);
    $finish;
  end
endmodule
