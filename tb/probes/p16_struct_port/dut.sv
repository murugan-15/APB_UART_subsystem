// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 murugan-15
//
// p16: a packed struct, typedef'd in a package, on a module port. This is how
// RTL bundles related signals now that interfaces are not allowed in rtl/
// (conventions rule 2, D-011). Package-qualified names, no import (rule 1).
//
// The default build assigns the struct member by member: the PORTABLE form.
//   -DNAMED_PATTERN  assigns with a named assignment pattern '{data: ..., valid: ...}
//                    (pinned as its own check: not every tool accepts it)
package p16_pkg;
  typedef struct packed {
    logic [7:0] data;
    logic       valid;
  } bus_t;                                   // 9 bits
endpackage

module p16_src (input logic clk, input logic rst_n, output p16_pkg::bus_t o);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) o <= '0;
`ifdef NAMED_PATTERN
    else        o <= '{data: o.data + 8'd1, valid: 1'b1};
`else
    else begin
      o.data  <= o.data + 8'd1;
      o.valid <= 1'b1;
    end
`endif
endmodule

module p16_dut (input logic clk, input logic rst_n, output logic [7:0] last);
  p16_pkg::bus_t b;
  p16_src u_src (.clk(clk), .rst_n(rst_n), .o(b));
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)       last <= '0;
    else if (b.valid) last <= b.data;
endmodule
