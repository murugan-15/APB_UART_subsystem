// p02: parameterized interface with modports, connected through two
// submodules. The APB slave port may be written this way, so every tool
// in the flow must accept it.
interface p02_bus_if #(parameter int W = 8);
  logic [W-1:0] data;
  logic         valid;
  logic         ready;
  modport src (output data, valid, input ready);
  modport snk (input data, valid, output ready);
endinterface

module p02_src (input logic clk, input logic rst_n, p02_bus_if.src bus);
  logic [7:0] cnt;
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)                     cnt <= '0;
    else if (bus.valid && bus.ready) cnt <= cnt + 8'd1;
  assign bus.data  = cnt;
  assign bus.valid = 1'b1;
endmodule

module p02_snk (input logic clk, input logic rst_n, p02_bus_if.snk bus,
                output logic [7:0] last);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)                     last <= '0;
    else if (bus.valid && bus.ready) last <= bus.data;
  assign bus.ready = 1'b1;
endmodule

module p02_dut (input logic clk, input logic rst_n, output logic [7:0] last);
  p02_bus_if #(.W(8)) bus ();
  p02_src u_src (.clk(clk), .rst_n(rst_n), .bus(bus));
  p02_snk u_snk (.clk(clk), .rst_n(rst_n), .bus(bus), .last(last));
endmodule
