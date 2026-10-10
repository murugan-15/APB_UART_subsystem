// p03: package with parameters / typedef / function, package import in the
// module header, $clog2, packed 2-D ports and a generate-for loop.
package p03_pkg;
  parameter  int DEPTH = 8;
  localparam int AW    = $clog2(DEPTH);
  typedef logic [AW-1:0] addr_t;
  function automatic logic parity(input logic [7:0] d);
    return ^d;
  endfunction
endpackage

module p03_dut
  import p03_pkg::*;
#(
  parameter int N = 4
) (
  input  logic [N-1:0][7:0] d,
  output logic [N-1:0]      par,
  output addr_t             last_addr
);
  for (genvar i = 0; i < N; i++) begin : g_lane
    assign par[i] = parity(d[i]);
  end
  assign last_addr = addr_t'(DEPTH - 1);
endmodule
