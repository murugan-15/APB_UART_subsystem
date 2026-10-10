// p01: core synthesizable SystemVerilog -- logic, typedef enum / packed
// struct, always_ff / always_comb, unique case, async active-low reset.
module p01_dut (
  input  logic       clk,
  input  logic       rst_n,
  input  logic [7:0] din,
  input  logic       valid,
  output logic [8:0] sum,
  output logic [1:0] st
);
  typedef enum logic [1:0] {IDLE = 2'd0, ACC = 2'd1, DONE = 2'd2} state_t;
  typedef struct packed {
    logic [3:0] hi;
    logic [3:0] lo;
  } nib_t;

  state_t state, next;
  nib_t   n;

  always_comb n = din;

  always_comb begin
    next = state;
    unique case (state)
      IDLE:    if (valid)  next = ACC;
      ACC:     if (!valid) next = DONE;
      DONE:    next = IDLE;
      default: next = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sum   <= '0;
    end else begin
      state <= next;
      if (valid) sum <= sum + {5'b0, n.hi} + {5'b0, n.lo};
    end
  end

  assign st = state;
endmodule
