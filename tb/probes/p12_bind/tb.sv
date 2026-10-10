module p12_tb;
  logic clk = 1'b0, a = 1'b0, y;

  p12_dut dut (.*);

  always #5 clk = ~clk;

  initial begin
    for (int k = 0; k < 10; k++) @(posedge clk) a <= ~a;  // toggle every cycle (p04 style)
    @(negedge clk);
    if (dut.u_chk.fired_good == 0 && dut.u_chk.fired_bad > 0) $display("PROBE_PASS");
    else $display("PROBE_FAIL good=%0d bad=%0d", dut.u_chk.fired_good, dut.u_chk.fired_bad);
    $finish;
  end
endmodule
