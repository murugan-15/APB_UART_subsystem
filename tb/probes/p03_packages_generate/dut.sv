// p03: package with parameters / typedef / function, $clog2, packed 2-D
// ports and a generate-for loop.
//
// The default build is the PORTABLE form, the one RTL in this project must use.
// Yosys 0.69's open-source frontend has no `import` (header, body, or file
// scope) and no `return` statement in functions. So RTL uses package-
// qualified names (p03_pkg::...) and Verilog-2001 function-name assignment.
// Each unsupported form is pinned by its own define / check:
//   -DHEADER_IMPORT  import in the module header
//   -DBODY_IMPORT    import inside the module body
//   -DUSE_RETURN     `return` in a function
package p03_pkg;
  parameter  int DEPTH = 8;
  localparam int AW    = $clog2(DEPTH);
  typedef logic [AW-1:0] addr_t;
  function automatic logic parity(input logic [7:0] d);
`ifdef USE_RETURN
    return ^d;
`else
    parity = ^d;
`endif
  endfunction
endpackage

`ifdef HEADER_IMPORT
module p03_dut
  import p03_pkg::*;
#(
  parameter int N = 4
) (
  input  logic [N-1:0][7:0] d,
  output logic [N-1:0]      par,
  output addr_t             last_addr
);
`else
module p03_dut #(
  parameter int N = 4
) (
  input  logic [N-1:0][7:0] d,
  output logic [N-1:0]      par,
  output p03_pkg::addr_t    last_addr
);
`endif
`ifdef BODY_IMPORT
  import p03_pkg::*;
`endif

  for (genvar i = 0; i < N; i++) begin : g_lane
    assign par[i] = p03_pkg::parity(d[i]);
  end
  assign last_addr = p03_pkg::addr_t'(p03_pkg::DEPTH - 1);
endmodule
