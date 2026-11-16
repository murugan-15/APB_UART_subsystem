// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
//
// p23: svlint with the project rule file (.svlint.toml, conventions section 3).
// This file follows the rules and must pass.
`default_nettype none
module p23_clean #(parameter int WIDTH = 4) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);
  typedef enum logic [1:0] {IDLE, RUN} state_t;
  state_t state_q, state_d;

  always_comb begin
    state_d = state_q;
    case (state_q)
      IDLE:    state_d = RUN;
      RUN:     state_d = IDLE;
      default: state_d = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      state_q <= IDLE;
      q       <= '0;
    end else begin
      state_q <= state_d;
      if (state_q == RUN) q <= d;
    end
endmodule
`default_nettype wire
