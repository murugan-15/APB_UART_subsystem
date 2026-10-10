// p01 testbench. Stimulus is driven at negedge so DUT sampling at posedge
// is race-free (see p04 / BUG-001).
module p01_tb;
  logic       clk = 1'b0, rst_n = 1'b0, valid = 1'b0;
  logic [7:0] din = '0;
  logic [8:0] sum;
  logic [1:0] st;
  int         errors = 0;

  p01_dut dut (.*);

  always #5 clk = ~clk;

  task automatic expect_eq(input string what, input logic [31:0] got, input logic [31:0] exp);
    if (got !== exp) begin
      errors++;
      $display("MISMATCH %s got=%0d exp=%0d", what, got, exp);
    end
  endtask

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1'b1;
    @(negedge clk);
    valid = 1'b1;
    din   = 8'h12;
    repeat (3) @(negedge clk);          // three posedges with valid=1
    valid = 1'b0;
    expect_eq("st==ACC", 32'(st), 1);
    expect_eq("sum", 32'(sum), 9);           // 3 * (1 + 2)
    @(negedge clk) expect_eq("st==DONE", 32'(st), 2);
    @(negedge clk) expect_eq("st==IDLE", 32'(st), 0);
    if (errors == 0) $display("PROBE_PASS");
    else             $display("PROBE_FAIL errors=%0d", errors);
    $finish;
  end
endmodule
