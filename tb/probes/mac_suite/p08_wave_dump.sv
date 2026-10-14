// Probe P08 — waveform dump. The dump format is chosen by the tool flags, not the SV:
// FST via `--trace-fst` (Verilator) or `vvp -fst` (Icarus; default is VCD).
// NOTE: a comment whose first word is "verilator" is parsed by Verilator as a pragma.
// scripts/probe.sh checks the file exists and is FST (binary header) rather than VCD (text).

module p08_wave_dump;
  logic       clk = 1'b0;
  logic [7:0] cnt = 8'd0;

  always #5 clk = ~clk;
  always @(posedge clk) cnt <= cnt + 8'd1;

  initial begin
    string path;
    if (!$value$plusargs("dump=%s", path)) path = "p08.fst";
    $dumpfile(path);
    $dumpvars(0, p08_wave_dump);
    repeat (16) @(posedge clk);
    $display("PROBE PASS: p08_wave_dump wrote %s", path);
    $finish;
  end
endmodule
