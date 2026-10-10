// p07b: does a failing assertion with the DEFAULT action ($error) make the
// simulator exit nonzero? If not, the regression must grep logs for errors
// rather than trust the exit code.
module p07_tb_exit;
  initial begin
    #1;
    a_must_fail: assert (1'b0);
    #1;
    $display("reached end");
    $finish;
  end
endmodule
