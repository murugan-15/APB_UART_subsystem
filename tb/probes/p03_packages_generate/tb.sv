module p03_tb;
  import p03_pkg::*;
  logic [3:0][7:0] d;
  logic [3:0]      par;
  addr_t           last_addr;
  int              errors = 0;

  p03_dut #(.N(4)) dut (.*);

  initial begin
    d = {8'h00, 8'h01, 8'h03, 8'h07};   // lanes 3..0 -> parity 0,1,0,1
    #1;
    if (par !== 4'b0101)  begin errors++; $display("par=%b", par); end
    if ($bits(addr_t) != 3) begin errors++; $display("AW=%0d", $bits(addr_t)); end
    if (last_addr !== 3'd7) begin errors++; $display("last_addr=%0d", last_addr); end
    if (errors == 0) $display("PROBE_PASS");
    else             $display("PROBE_FAIL errors=%0d", errors);
    $finish;
  end
endmodule
