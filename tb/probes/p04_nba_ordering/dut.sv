// p04: two-stage register pipeline. The point of the probe is the testbench
// drive/sample discipline, not the DUT.
module p04_dut (input logic clk, input logic [7:0] d, output logic [7:0] q2);
  logic [7:0] q1;
  always_ff @(posedge clk) begin
    q1 <= d;
    q2 <= q1;
  end
endmodule
