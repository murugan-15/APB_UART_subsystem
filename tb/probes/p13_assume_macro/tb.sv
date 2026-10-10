// p13 sim: same RTL, ASSUME expands to assert.
//   p13_tb_legal   : obeys the obligation       -> must finish with PROBE_PASS
//   p13_tb_illegal : start with len == 0        -> the assertion must fire
module p13_tb_legal;
  logic clk = 1'b0, rst = 1'b1, start = 1'b0, busy;
  logic [3:0] len = '0;
  p13_dut dut (.*);
  always #5 clk = ~clk;
  initial begin
    repeat (2) @(posedge clk);
    rst   <= 1'b0;
    // len before start: the combinational check must never see start=1 with
    // the old len=0, even if the simulator interleaves NBA updates.
    @(posedge clk) begin len <= 4'd3; start <= 1'b1; end
    @(posedge clk) start <= 1'b0;
    repeat (6) @(posedge clk);
    if (!busy) $display("PROBE_PASS");
    else       $display("PROBE_FAIL busy stuck");
    $finish;
  end
endmodule

module p13_tb_illegal;
  logic clk = 1'b0, rst = 1'b1, start = 1'b0, busy;
  logic [3:0] len = '0;
  p13_dut dut (.*);
  always #5 clk = ~clk;
  initial begin
    repeat (2) @(posedge clk);
    rst   <= 1'b0;
    @(posedge clk) begin start <= 1'b1; len <= 4'd0; end   // violates obligation
    @(posedge clk) start <= 1'b0;
    repeat (4) @(posedge clk);
    $display("reached end");
    $finish;
  end
endmodule
