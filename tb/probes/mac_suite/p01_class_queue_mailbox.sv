// Probe P01 — classes (incl. inheritance + virtual methods), queues, mailboxes.
// Needed for: modular TB (transaction / driver / monitor / scoreboard).
// Self-checking: prints "PROBE PASS" or calls $fatal (nonzero exit).

module p01_class_queue_mailbox;

  class txn;
    int        id;
    bit [7:0]  data;
    function new(int id, bit [7:0] data);
      this.id   = id;
      this.data = data;
    endfunction
    virtual function string kind();
      return "base";
    endfunction
  endclass

  class txn_err extends txn;
    function new(int id, bit [7:0] data);
      super.new(id, data);
    endfunction
    virtual function string kind();
      return "err";
    endfunction
  endclass

  mailbox #(txn) mbx;
  txn            q[$];
  int            errors = 0;

  initial begin
    mbx = new();

    // Producer and consumer run concurrently and communicate only via the mailbox.
    fork
      begin : producer
        txn t;  // declared without initializer: a static-lifetime initializer would run once only
        for (int i = 0; i < 4; i++) begin
          if (i == 3) begin
            txn_err e;
            e = new(i, 8'(i * 3));
            t = e;                  // upcast: base handle to derived object
          end else begin
            t = new(i, 8'(i * 3));
          end
          mbx.put(t);
          #1;
        end
      end
      begin : consumer
        txn r;
        for (int i = 0; i < 4; i++) begin
          mbx.get(r);
          q.push_back(r);
        end
      end
    join

    if (q.size() != 4) begin
      errors++; $display("ERROR: queue size %0d, expected 4", q.size());
    end
    for (int i = 0; i < 4; i++) begin
      txn r;
      r = q.pop_front();
      if (r.id != i || r.data != 8'(i * 3)) begin
        errors++; $display("ERROR: item %0d out of order or corrupted (id=%0d data=%0h)", i, r.id, r.data);
      end
      // Virtual dispatch: the last item is a txn_err seen through a txn handle.
      if (r.kind() != ((i == 3) ? "err" : "base")) begin
        errors++; $display("ERROR: item %0d virtual dispatch returned '%s'", i, r.kind());
      end
    end
    if (q.size() != 0) begin
      errors++; $display("ERROR: queue not empty after pops");
    end

    if (errors == 0) $display("PROBE PASS: p01_class_queue_mailbox");
    else             $fatal(1, "PROBE FAIL: p01_class_queue_mailbox (%0d errors)", errors);
    $finish;
  end

endmodule
