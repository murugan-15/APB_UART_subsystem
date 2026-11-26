// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
//
// Ported from the original Mac suite (tb/probes/mac_suite) on 2026-11-15, milestone M0b.
// p26 — covergroup / coverpoint (explicit bins) / cross, queried with
// get_inst_coverage(). Needed for: functional coverage.
// Finding (M0): Verilator 5.050 returns 0 from type-level get_coverage() even when bins are
// hit, and rejects per-coverpoint calls (cov.cp_a.get_coverage()). The type-level query is
// pinned by its own check (-DTYPE_COV, a known FAIL).
// Self-checking: after one sample the instance coverage must be 37.50 (3 of the 8 bins: one
// of 2, one of 2, one of 4), and exactly 100 after all bins are hit. A tool that parses
// covergroups but never counts fails. 37.50 is what Verilator 5.050 returns (bins hit over
// bins); IEEE 1800-2023 19.11 defines the weighted average over coverpoints and crosses, which
// gives 41.67 here (checked 2026-11-26, conventions 2.1), so this pins the tool, not the standard.

module p26_tb;

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
    if (c_partial < 37.49 || c_partial > 37.51) begin
      errors++; $display("ERROR: partial coverage %0.2f, expected 37.50", c_partial);
    end
    if (c_full < 99.99) begin
      errors++; $display("ERROR: full coverage %0.2f, expected 100", c_full);
    end
`ifdef TYPE_COV
    // -DTYPE_COV: the type-level query must also report 100. Pinned as its own check,
    // because it returns 0 on the pinned Verilator even when every bin is hit.
    if (cov.get_coverage() < 99.99) begin
      errors++; $display("ERROR: type-level get_coverage() %0.2f, expected 100", cov.get_coverage());
    end
`endif

    if (errors == 0) $display("PROBE_PASS");
    else             $fatal(1, "PROBE_FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
