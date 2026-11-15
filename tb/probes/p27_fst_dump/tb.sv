// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 murugan-15
//
// Ported from the original Mac suite (tb/probes/mac_suite) on 2026-11-15, milestone M0b.
// p27 — waveform dump. The dump format is chosen by the tool flags, not the SV:
// FST via `--trace-fst` (Verilator) or `vvp -fst` (Icarus; default is VCD).
// NOTE: a comment whose first word is "verilator" is parsed by Verilator as a pragma.
// The runner checks the file exists and is FST (binary header) rather than VCD (text).

module p27_tb;
  logic       clk = 1'b0;
  logic [7:0] cnt = 8'd0;

  always #5 clk = ~clk;
  always @(posedge clk) cnt <= cnt + 8'd1;

  initial begin
    string path;
    if (!$value$plusargs("dump=%s", path)) path = "p27.fst";
    $dumpfile(path);
    $dumpvars(0, p27_tb);
    repeat (16) @(posedge clk);
    $display("PROBE_PASS wrote %s", path);
    $finish;
  end
endmodule
