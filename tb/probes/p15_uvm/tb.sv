// p15: UVM availability. Needs UVM_HOME pointing at an Accellera UVM
// source tree; reports UNAVAIL without one. Per D-003, UVM work runs on EDA
// Playground, so UNAVAIL here is the expected local baseline.
`include "uvm_macros.svh"
module p15_tb;
  import uvm_pkg::*;

  class p15_test extends uvm_test;
    `uvm_component_utils(p15_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      `uvm_info("P15", "PROBE_PASS", UVM_NONE)
      phase.drop_objection(this);
    endtask
  endclass

  initial run_test("p15_test");
endmodule
