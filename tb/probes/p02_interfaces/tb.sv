module p02_tb;
  logic       clk = 1'b0, rst_n = 1'b0;
  logic [7:0] last;

  p02_dut dut (.*);

  always #5 clk = ~clk;

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1'b1;
    repeat (5) @(negedge clk);   // after k posedges: cnt == k, last == k-1
    if (last === 8'd4) $display("PROBE_PASS");
    else               $display("PROBE_FAIL last=%0d", last);
    $finish;
  end
endmodule
