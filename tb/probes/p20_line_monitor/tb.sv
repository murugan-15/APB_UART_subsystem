// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 murugan-15
//
// p20: an independent line monitor. A behavioral transmitter sends three 8N1
// bytes at 115200 baud; the testbench dumps a VCD; scripts/vcd_pin.py extracts
// the tx pin; sigrok-cli's UART decoder (third-party code that shares nothing
// with our RTL or its baud tick) must read back 41 55 A5. Decoding the same
// capture at half the baud rate must NOT give those bytes (anti-vacuity).
`timescale 1ns/1ns
module p20_tb;
  localparam int BIT_NS = 8680;              // 1 / 115200 s, to the nearest 10 ns
  logic tx;
  task automatic send(input logic [7:0] d);
    tx = 1'b0; #(BIT_NS);                    // start bit
    for (int i = 0; i < 8; i++) begin
      tx = d[i]; #(BIT_NS);                  // data, LSB first
    end
    tx = 1'b1; #(BIT_NS);                    // stop bit
  endtask
  initial begin
    $dumpfile("tx.vcd");
    $dumpvars(0, p20_tb);
    tx = 1'b1; #(4 * BIT_NS);
    send(8'h41); send(8'h55); send(8'hA5);
    #(4 * BIT_NS);
    $display("PROBE_PASS");
    $finish;
  end
endmodule
