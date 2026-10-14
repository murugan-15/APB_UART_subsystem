// Probe P09 — the ASSUME macro in simulation: `ASSUME must behave as an assertion.
// Also exercises `include of a shared header.
// Self-checking: a legal input must not fire it; an illegal input must fire it.

`include "probe_assume.svh"

module p09_assume_macro;
  logic       clk = 1'b0;
  logic       load = 1'b0;
  logic [3:0] ld_val = 4'd0;
  int         viol = 0;

  always #5 clk = ~clk;

  // Same constraint text as tb/probes/formal/f01_past_assert.sv.
  always @(posedge clk) begin
    if (load) begin
      `ASSUME (ld_val <= 4'd9) else viol++;   // `else` is the assertion's fail action
    end
  end

  initial begin
    int viol_after_legal;
    @(negedge clk); load = 1'b1; ld_val = 4'd9;     // legal
    @(negedge clk); load = 1'b0;
    @(negedge clk);
    viol_after_legal = viol;
    load = 1'b1; ld_val = 4'd12;                    // illegal: must fire
    @(negedge clk); load = 1'b0;
    @(negedge clk);

    $display("INFO: violations after legal=%0d, after illegal=%0d", viol_after_legal, viol);
    if (viol_after_legal == 0 && viol == 1) $display("PROBE PASS: p09_assume_macro");
    else $fatal(1, "PROBE FAIL: p09_assume_macro (legal=%0d total=%0d; expected 0 and 1)",
                viol_after_legal, viol);
    $finish;
  end
endmodule
