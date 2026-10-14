// Probe P07 — Verilator --coverage (line + toggle).
// The SV is trivial on purpose; the probe is the flow: build with --coverage, run, then
// scripts/probe.sh checks that coverage.dat exists and `verilator_coverage --annotate`
// produces annotated source. One branch is deliberately never taken so the annotation
// must show a zero-count line (proof the counts are real, not all-hit).

module p07_code_coverage;
  logic       clk = 1'b0;
  logic [3:0] cnt = 4'd0;
  int         taken = 0, never = 0;

  always #5 clk = ~clk;

  always @(posedge clk) begin
    cnt <= cnt + 4'd1;
    if (cnt < 4'd15) taken++;
    else             never++;      // never reached: run stops before cnt == 15
  end

  initial begin
    repeat (10) @(posedge clk);
    $display("PROBE PASS: p07_code_coverage ran (taken=%0d never=%0d)", taken, never);
    $finish;
  end
endmodule
