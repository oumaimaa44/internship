/**********************************************************************\
*                               AsteRISC                               *
************************************************************************
*
* Copyright (C) 2022 Jonathan Saussereau
*
* This file is part of AsteRISC.
* AsteRISC is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
* 
* AsteRISC is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
* 
* You should have received a copy of the GNU General Public License
* along with AsteRISC. If not, see <https://www.gnu.org/licenses/>.
*
*/


//! Return Address Stack: predicts where a `ret` goes.
//!
//! A return is the one control transfer a branch target buffer cannot learn.
//! Its target is not a property of its address -- the same `ret` goes back to a
//! different caller every time it runs -- so a buffer that remembers the last
//! target is wrong on every call site but one. What *is* predictable is the
//! discipline: calls and returns nest, so the address a return will go to is
//! the one pushed by the call that has not returned yet.
//!
//! The stack is driven entirely by the front-end, on predicted control
//! transfers, before anyone knows what the instructions really are:
//!
//!   * a predicted call pushes the address the call would return to,
//!   * a predicted return pops it and hands it out as the target.
//!
//! Speculation
//! -----------
//! Pushes and pops therefore happen on paths that turn out to be wrong, and the
//! stack drifts. Nothing here repairs that, deliberately: a repair mechanism
//! costs a shadow pointer per in-flight transfer and buys very little on a core
//! this size, where the mispredicted window is a handful of instructions. The
//! consequence is bounded -- a drifted stack predicts a wrong target, which is
//! a misprediction like any other and is repaired by the ordinary redirection
//! path once the return resolves. Correctness never rests on the stack being
//! right, only performance does.
//!
//! Depth
//! -----
//! `p_ras_entries` is the whole cost/accuracy trade-off, and it is a steep one:
//! a stack needs only to be as deep as the call nesting actually reached, and
//! then every extra entry is wasted. 2 entries already catch the leaf calls
//! that dominate an embedded workload; 4 to 8 cover ordinary nested code; past
//! 16 nothing is gained by anything a core of this class runs.
//!
//! The stack wraps rather than saturating. Overflowing therefore loses the
//! oldest return address, so a call chain deeper than the stack mispredicts on
//! the way out of the deepest frames and predicts correctly again inside them --
//! which is strictly better than a saturating stack, where the top entry is
//! overwritten and *every* return of the chain is wrong.

`ifndef __CPU_RAS__
`define __CPU_RAS__

module cpu_ras #(
  parameter p_ras_entries = 4             //! stack depth (0 = no stack)
)(
  input  wire          i_clk,             //! global clock
  input  wire          i_rst,             //! global reset

  input  wire          i_push,            //! a call is predicted: remember `i_push_pc`
  input  wire  [31: 0] i_push_pc,         //! the address the call would return to
  input  wire          i_pop,             //! a return is predicted: hand out the top

  output wire          o_valid,           //! the stack holds an address to return to
  output wire  [31: 0] o_top              //! ...and this is it
);

  localparam int DEPTH = (p_ras_entries < 1) ? 1 : p_ras_entries;
  localparam int PTR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  //! the fill level needs to count up to DEPTH inclusive, hence one bit more
  //! than the pointer that walks the entries
  localparam int CNT_W = $clog2(DEPTH + 1);

  generate
    if (p_ras_entries == 0) begin: g_ras
      assign o_valid = 1'b0;
      assign o_top   = 32'd0;
    end else begin: g_ras

      logic [31: 0]     stack_q [DEPTH];
      //! index of the entry a push would write, i.e. one past the top
      logic [PTR_W-1:0] ptr_q;
      //! how many entries are occupied, so that a return predicted before any
      //! call has been seen predicts nothing instead of predicting garbage
      logic [CNT_W-1:0] count_q;

      wire  [PTR_W-1:0] top_idx  = ptr_q - PTR_W'(1);
      wire              occupied = (count_q != '0);

      //! A push and a pop in the same cycle cancel out. That is not a corner
      //! case to be tolerated but the common one: `jalr ra, ...` at the end of
      //! a tail call is a return and a call at once, and the stack depth it
      //! leaves behind is unchanged.
      wire              push = i_push;
      wire              pop  = i_pop & occupied;

      always_ff @(posedge i_clk) begin: stack
        if (i_rst) begin
          ptr_q   <= '0;
          count_q <= '0;
          for (int k = 0; k < DEPTH; k++) begin
            stack_q[k] <= 32'd0;
          end
        end else begin
          if (push && !pop) begin
            stack_q[ptr_q] <= i_push_pc;
            ptr_q          <= ptr_q + PTR_W'(1);
            //! the count stops at the depth: past that the pointer wraps and
            //! the oldest frame is what is being overwritten, so the stack is
            //! full, not fuller
            if (count_q != CNT_W'(DEPTH)) begin
              count_q <= count_q + CNT_W'(1);
            end
          end else if (pop && !push) begin
            ptr_q   <= top_idx;
            count_q <= count_q - CNT_W'(1);
          end else if (push && pop) begin
            //! the popped frame is replaced by the pushed one in place
            stack_q[top_idx] <= i_push_pc;
          end
        end
      end

      assign o_valid = occupied;
      assign o_top   = stack_q[top_idx];
    end
  endgenerate

endmodule

`endif // __CPU_RAS__
