// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 murugan-15
//
// p15: UVM on Verilator (D-012). Needs UVM_HOME pointing at a UVM source tree
// with a Verilator DPI backend (scripts/install_toolchain.sh installs
// CHIPS Alliance's uvm-verilator); reports UNAVAIL without one.
//   +UVM_ERR  raises one uvm_error: the anti-vacuity run. A UVM error does not
//             change the exit code, so the verdict must read the report counts.
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
      if ($test$plusargs("UVM_ERR")) `uvm_error("P15", "planted error")
      `uvm_info("P15", "PROBE_PASS", UVM_NONE)
      phase.drop_objection(this);
    endtask
  endclass

  initial run_test("p15_test");
endmodule
