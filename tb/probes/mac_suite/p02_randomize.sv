// Probe P02 — randomize() with class constraints, implication, and inline `with`.
// Needed for: constrained-random tests.
// Self-checking: every result must satisfy its constraints AND the values must actually vary
// (a tool that ignores randomize() and leaves fields at 0 must not pass).

module p02_randomize;

  class pkt;
    rand bit [7:0] len;
    rand bit [3:0] kind;
    constraint c_len  { len inside {[4:16]}; }
    constraint c_kind { kind == 4'd0 -> len < 8'd8; }   // implication
  endclass

  int errors = 0;

  initial begin
    pkt p;
    bit seen_len[256];
    int n_distinct = 0;
    p = new();

    for (int i = 0; i < 200; i++) begin
      if (p.randomize() != 1) begin
        errors++; $display("ERROR: randomize() returned failure at iteration %0d", i);
      end
      if (p.len < 8'd4 || p.len > 8'd16) begin
        errors++; $display("ERROR: c_len violated: len=%0d", p.len);
      end
      if (p.kind == 4'd0 && p.len >= 8'd8) begin
        errors++; $display("ERROR: c_kind violated: kind=0 len=%0d", p.len);
      end
      if (!seen_len[p.len]) begin
        seen_len[p.len] = 1'b1;
        n_distinct++;
      end
    end
    // 13 legal values over 200 draws: anything below 5 distinct means it is not really random.
    if (n_distinct < 5) begin
      errors++; $display("ERROR: only %0d distinct len values in 200 draws", n_distinct);
    end

    // Inline constraint must combine with the class constraints.
    for (int i = 0; i < 20; i++) begin
      if (p.randomize() with { len == 8'd10; } != 1) begin
        errors++; $display("ERROR: inline randomize() with failed");
      end
      if (p.len != 8'd10) begin
        errors++; $display("ERROR: inline constraint ignored: len=%0d", p.len);
      end
      if (p.kind == 4'd0) begin
        errors++; $display("ERROR: kind=0 with len=10 violates c_kind");
      end
    end

    if (errors == 0) $display("PROBE PASS: p02_randomize (%0d distinct len values)", n_distinct);
    else             $fatal(1, "PROBE FAIL: p02_randomize (%0d errors)", errors);
    $finish;
  end

endmodule
