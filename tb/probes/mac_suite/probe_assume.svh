// ASSUME macro pattern (conventions.md §5).
// Under FORMAL: an environment constraint (the solver only explores inputs that satisfy it).
// In simulation: an assertion, so the testbench is checked against the same constraint.
// One source line, two roles: sim and formal cannot disagree about what is legal input.

`ifndef PROBE_ASSUME_SVH
`define PROBE_ASSUME_SVH

`ifdef FORMAL
  `define ASSUME assume
`else
  `define ASSUME assert
`endif

`endif
