// Probe P05 — `bind`: attach a checker to a DUT without editing the DUT source, with the
// checker connected to a DUT-internal signal (cnt_q), which is the real use case.
// Needed for: attaching assertion modules from assertions/.
// Self-checking: the bound checker counts clock edges and compares cnt_q against its own
// shadow model; the top reads the checker's counters through the hierarchical path of the
// bound instance (u_dut.u_chk), which also proves the instance really exists there.
// (No package variables: Icarus 13 rejects `pkg::var = ...`, which would confound this probe.)

// "DUT": a free-running 4-bit counter. Knows nothing about the checker.
module p05_dut (
  input  logic clk,
  input  logic rst_n
);
  logic [3:0] cnt_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt_q <= 4'd0;
    else        cnt_q <= cnt_q + 4'd1;
  end
endmodule

// Checker: observes only, never drives the DUT.
module p05_checker (
  input logic       clk,
  input logic       rst_n,
  input logic [3:0] cnt
);
  logic [3:0] shadow = 4'd0;
  int         hits   = 0;
  int         errors = 0;
  always @(posedge clk) begin
    if (rst_n) begin
      hits++;
      if (cnt != shadow) errors++;
      shadow <= shadow + 4'd1;
    end
  end
endmodule

bind p05_dut p05_checker u_chk (.clk(clk), .rst_n(rst_n), .cnt(cnt_q));

module p05_bind;
  logic clk   = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  p05_dut u_dut (.clk(clk), .rst_n(rst_n));

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1'b1;
    repeat (20) @(negedge clk);

    $display("INFO: checker hits=%0d errors=%0d", u_dut.u_chk.hits, u_dut.u_chk.errors);
    if (u_dut.u_chk.hits >= 20 && u_dut.u_chk.errors == 0) $display("PROBE PASS: p05_bind");
    else $fatal(1, "PROBE FAIL: p05_bind (hits=%0d, errors=%0d)", u_dut.u_chk.hits, u_dut.u_chk.errors);
    $finish;
  end
endmodule
