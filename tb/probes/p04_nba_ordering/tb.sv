// p04: race-free TB convention (fix for BUG-001).
// Drive DUT inputs with NONBLOCKING assignments at the active clock edge and
// check outputs at the opposite edge. The DUT's always_ff then always reads
// the old value of d at posedge k, whatever order the simulator runs the TB
// and DUT processes in, so every simulator must give the same answer.
// A BLOCKING drive at posedge (the BUG-001 pattern) lets the result depend
// on process scheduling order, so it differs between simulators.
module p04_tb;
  logic       clk = 1'b0;
  logic [7:0] d = '0;
  logic [7:0] q2;
  int         errors = 0;

  p04_dut dut (.*);

  always #5 clk = ~clk;

  function automatic logic [7:0] v(input int k);
    return 8'(k * 7 + 3);
  endfunction

  initial begin
    for (int k = 0; k < 20; k++) begin
      @(posedge clk) d <= v(k);
      // At posedge k the DUT captured d == v(k-1) into q1 and v(k-2) into q2.
      @(negedge clk);
      if (k >= 2 && q2 !== v(k - 2)) begin
        errors++;
        $display("k=%0d q2=%0d exp=%0d", k, q2, v(k - 2));
      end
    end
    if (errors == 0) $display("PROBE_PASS");
    else             $display("PROBE_FAIL errors=%0d", errors);
    $finish;
  end
endmodule
