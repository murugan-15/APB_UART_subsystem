// p06: constrained random -- rand fields, constraint blocks with inside and
// implication, randomize() with {...}. Verilator solves constraints with an
// external SMT solver (z3), so this probe also checks that the solver is set up.
class p06_pkt;
  rand bit [7:0] len;
  rand bit [3:0] kind;
  constraint c_len  { len inside {[4:20]}; }
  constraint c_kind { kind != 0; (kind == 1) -> len < 8; }
endclass

module p06_tb;
  initial begin
    // No initializers here: in an initial block they would be implicitly
    // static (Verilator IMPLICITSTATIC lint). Assign in the body instead.
    p06_pkt   p;
    int       errors;
    int       ok;
    bit [7:0] lo, hi;

    p      = new;
    errors = 0;
    lo     = 8'hFF;
    hi     = 8'h00;

    repeat (200) begin
      ok = p.randomize();
      if (ok == 0) errors++;
      if (!(p.len inside {[4:20]}) || p.kind == 0 || (p.kind == 1 && p.len >= 8)) begin
        errors++;
        $display("constraint violated: len=%0d kind=%0d", p.len, p.kind);
      end
      if (p.len < lo) lo = p.len;
      if (p.len > hi) hi = p.len;
    end
    // Anti-vacuity: if randomize() returned 1 but never changed the values,
    // every check above would still pass. Require a real spread of values.
    if (hi - lo < 8) begin
      errors++;
      $display("no spread: lo=%0d hi=%0d", lo, hi);
    end

    ok = p.randomize() with { len == 5; };
    if (ok == 0 || p.len != 5) begin
      errors++;
      $display("inline with failed: ok=%0d len=%0d", ok, p.len);
    end

    if (errors == 0) $display("PROBE_PASS");
    else             $display("PROBE_FAIL errors=%0d", errors);
    $finish;
  end
endmodule
