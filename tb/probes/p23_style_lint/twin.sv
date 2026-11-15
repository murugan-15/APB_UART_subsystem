// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 murugan-15
//
// p23 anti-vacuity: one violation of every rule that .svlint.toml switches on. The probe
// reads the rule names from the rule file and requires each of them in svlint's report,
// so a rule added to the file without a violation here fails the probe.
// (This file has no `default_nettype none: that is the first violation.)
interface p23_if;                              // an interface, with a modport
  logic v;
  modport sink (input v);
endinterface

module p23_nonansi (a, y);                     // non-ANSI port list
  input a;
  output y;
  assign y = a;
endmodule

module p23_twin #(
  parameter int width = 2                      // parameter not UPPER_CASE
) (
  input  logic       clk,
  input  logic [1:0] sel,
  input  logic       a,
  p23_if.sink        bus,                      // interface port
  output logic       q,
  output logic       r,
  output logic       s,
  output logic       t,
  output logic       u
);
  localparam int depth = width;                // localparam not UPPER_CASE
  typedef enum { IDLE, BUSY } state_t;         // enum without a base type
  state_t st;
  always_ff @(posedge clk) q = a;              // blocking assignment in always_ff
  always @(posedge clk) r <= a;                // plain always
  always_latch if (a) s <= bus.v;              // always_latch
  always_comb t <= a;                          // nonblocking assignment in always_comb
  always_comb begin
    st = (depth > 1) ? BUSY : IDLE;
    u  = 1'b0;
    case (sel)                                 // case without a default
      2'd0: u = a;
      2'd1: u = ~a;
    endcase
  end
endmodule
