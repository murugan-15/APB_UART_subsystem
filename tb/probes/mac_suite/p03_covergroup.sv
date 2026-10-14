// Probe P03 — covergroup / coverpoint (explicit bins) / cross, queried with
// get_inst_coverage(). Needed for: functional coverage.
// Finding (M0): Verilator 5.050 returns 0 from type-level get_coverage() even when bins are
// hit, and rejects per-coverpoint calls (cov.cp_a.get_coverage()). get_type_cov is printed
// as INFO only, so the probe tests the API that the TB will actually rely on.
// Self-checking: coverage must be partial (0 < cov < 100) after a partial sample set and
// exactly 100 after all bins are hit. A tool that parses covergroups but never counts fails.

module p03_covergroup;

  bit [1:0] a;
  bit       b;
  int       errors = 0;

  covergroup cg;
    cp_a: coverpoint a {
      bins lo = {0, 1};
      bins hi = {2, 3};
    }
    cp_b: coverpoint b;          // auto bins: 0, 1
    x_ab: cross cp_a, cp_b;      // 4 cross bins
  endgroup

  cg cov = new();

  initial begin
    real c_partial, c_full;

    a = 2'd0; b = 1'b0; cov.sample();
    c_partial = cov.get_inst_coverage();

    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 2; j++) begin
        a = 2'(i); b = 1'(j); cov.sample();
      end
    end
    c_full = cov.get_inst_coverage();

    $display("INFO: inst coverage partial=%0.2f full=%0.2f; type get_coverage()=%0.2f",
             c_partial, c_full, cov.get_coverage());
    if (!(c_partial > 0.0 && c_partial < 100.0)) begin
      errors++; $display("ERROR: partial coverage %0.2f not in (0,100)", c_partial);
    end
    if (c_full < 99.99) begin
      errors++; $display("ERROR: full coverage %0.2f, expected 100", c_full);
    end

    if (errors == 0) $display("PROBE PASS: p03_covergroup");
    else             $fatal(1, "PROBE FAIL: p03_covergroup (%0d errors)", errors);
    $finish;
  end

endmodule
