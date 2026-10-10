// p05: class-based testbench features: virtual class with pure virtual
// method, inheritance with super.new, dynamic dispatch, queue of handles.
module p05_tb;
  virtual class shape;
    pure virtual function int area();
  endclass

  class rect extends shape;
    int w, h;
    function new(int w, int h);
      this.w = w;
      this.h = h;
    endfunction
    virtual function int area();
      return w * h;
    endfunction
  endclass

  class square extends rect;
    function new(int s);
      super.new(s, s);
    endfunction
  endclass

  shape q[$];

  initial begin
    rect   r;
    square s;
    int    total;
    total = 0;
    r = new(2, 3);
    s = new(4);
    q.push_back(r);
    q.push_back(s);
    foreach (q[i]) total += q[i].area();
    if (total == 22 && q.size() == 2) $display("PROBE_PASS");
    else                              $display("PROBE_FAIL total=%0d", total);
    $finish;
  end
endmodule
