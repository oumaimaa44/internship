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


//! Branch Target Buffer: predicts, from a fetch address alone, that the
//! instruction about to be read is a taken control transfer, and where it goes.
//!
//! This is the one thing the decode-stage predictors (`cpu_static_branch_predictor`,
//! `cpu_dynamic_branch_predictor`) structurally cannot do. They sit on the
//! decoder outputs, so the earliest they can redirect the front-end is once the
//! instruction has come back from memory and been decoded: a correctly
//! predicted taken branch still costs every bubble between the fetch and the
//! decode slot. The buffer is read with the address being presented to the
//! instruction memory *this* cycle, and its answer picks the address presented
//! the next one, so a hit costs nothing at all.
//!
//! The price is that a prediction is made before anyone knows what the
//! instruction is. Everything the buffer says is therefore a guess about an
//! address, not about an opcode, and all of it is checked when the transfer
//! actually resolves. A stale entry, an aliased tag, an address that is no
//! longer a branch: all three come out as an ordinary misprediction, repaired
//! by the ordinary redirection path.
//!
//! Configuration
//! -------------
//! The parameters are meant to span the whole range from a buffer that costs a
//! few dozen flip-flops to one that catches nearly every transfer:
//!
//!   p_btb_entries  : total number of entries (0 removes the buffer entirely,
//!                    and with it every gate in this file). 8 entries already
//!                    covers the inner loops of a small benchmark; 64 is where
//!                    an embedded core stops gaining much.
//!   p_btb_ways     : associativity. 1 is a direct-mapped buffer -- cheapest,
//!                    and two hot branches that share an index evict each other
//!                    forever. 2 or 4 removes that pathology for a mux.
//!   p_btb_tag_bits : how much of the address is checked on a hit.
//!                    0 is a genuine design point, not a degenerate one: a
//!                    tagless buffer never *knows* it hit, it just predicts on
//!                    every fetch and is wrong whenever it aliased. Since a
//!                    wrong prediction is already a repairable event, trading
//!                    tag storage for mispredictions can be the right call at
//!                    the very low end.
//!   p_btb_ctr_bits : per-entry saturating counter deciding the direction of a
//!                    conditionnal branch. 0 predicts taken on every hit and
//!                    relies on allocation alone (an entry is only created by a
//!                    taken transfer), which is exactly a "taken branches only"
//!                    buffer. 1 or 2 lets an entry survive a not-taken outcome
//!                    instead of being destroyed by it.
//!   p_btb_repl     : replacement policy within a set, 0 = round-robin,
//!                    1 = pseudo-random (an LFSR shared by every set).
//!
//! Updates
//! -------
//! The buffer learns only from resolved transfers, in resolution order. There
//! is no speculative update and therefore nothing to repair: the cost is that
//! the entry for a branch appears one resolution late, which matters for a
//! branch executed twice and never again -- and those were never predictable.

`ifndef __CPU_BTB__
`define __CPU_BTB__

`ifdef VIVADO
 `include "packages/pck_control.sv"
`else
 `include "core/packages/pck_control.sv"
`endif

module cpu_btb
  import pck_control::*;
#(
  parameter p_btb_entries = 8,            //! total number of entries (0 = no buffer)
  parameter p_btb_ways    = 1,            //! associativity (1, 2 or 4)
  parameter p_btb_tag_bits = 8,           //! address bits checked on a hit (0 = tagless)
  parameter p_btb_ctr_bits = 1,           //! per-entry direction counter (0 = always taken)
  parameter p_btb_repl    = 0             //! replacement: 0 = round-robin, 1 = pseudo-random
)(
  input  wire          i_clk,             //! global clock
  input  wire          i_rst,             //! global reset

  // lookup: combinational, on the address being fetched this cycle
  input  wire  [31: 0] i_pc,              //! address presented to the instruction memory
  output wire          o_hit,             //! this address is a control transfer, predicted taken
  output wire  [31: 0] o_target,          //! ...and this is where it goes
  output bp_kind_e     o_kind,            //! what the buffer believes it is

  // update, when a control transfer resolves
  input  wire          i_upd_valid,       //! a control transfer resolved this cycle
  input  wire  [31: 0] i_upd_pc,          //! address of the instruction that resolved
  input  wire  [31: 0] i_upd_target,      //! the target it actually went to
  input  bp_kind_e     i_upd_kind,        //! what it actually was
  input  wire          i_upd_taken        //! ...and whether it was taken
);

  localparam int WAYS    = (p_btb_ways    < 1) ? 1 : p_btb_ways;
  localparam int SETS    = (p_btb_entries < WAYS) ? 1 : (p_btb_entries / WAYS);
  //! log2 of the set count, at least 1 so that every part select below stays
  //! legal even for a fully associative or single-set buffer
  localparam int SET_W   = (SETS <= 1) ? 1 : $clog2(SETS);
  localparam int WAY_W   = (WAYS <= 1) ? 1 : $clog2(WAYS);
  localparam int TAG_W   = (p_btb_tag_bits < 1) ? 1 : p_btb_tag_bits;
  localparam int CTR_W   = (p_btb_ctr_bits < 1) ? 1 : p_btb_ctr_bits;

  localparam logic [CTR_W-1:0] CTR_INIT = {1'b1, {(CTR_W-1){1'b0}}};
  localparam logic [CTR_W-1:0] CTR_MAX  = {CTR_W{1'b1}};
  localparam logic [CTR_W-1:0] CTR_MIN  = {CTR_W{1'b0}};

  generate
    if (p_btb_entries == 0) begin: g_btb
      //! no buffer: the front-end never predicts anything from an address alone
      assign o_hit    = 1'b0;
      assign o_target = 32'd0;
      assign o_kind   = bp_branch;
    end else begin: g_btb

      logic                valid_q  [SETS][WAYS];
      logic [TAG_W-1:0]    tag_q    [SETS][WAYS];
      logic [29: 0]        target_q [SETS][WAYS];
      bp_kind_e            kind_q   [SETS][WAYS];
      logic [CTR_W-1:0]    ctr_q    [SETS][WAYS];

      //! Address split. Bit 0 is always zero and bit 1 only ever varies on a
      //! core with compressed instructions, so both the index and the tag start
      //! at bit 1: two adjacent 32-bit branches then land in distinct sets
      //! without an index bit being spent on a case that may not exist.
      function automatic logic [SET_W-1:0] set_of(input logic [31:0] pc);
        set_of = (SETS <= 1) ? '0 : pc[SET_W:1];
      endfunction

      function automatic logic [TAG_W-1:0] tag_of(input logic [31:0] pc);
        //! the tag continues where the index stops, so that two addresses in
        //! the same set differ in their tag as early as possible
        tag_of = (p_btb_tag_bits < 1) ? '0
               : pc[((SETS <= 1) ? 1 : SET_W+1) +: TAG_W];
      endfunction

      /*******************************************************
        Lookup
      *******************************************************/

      wire  [SET_W-1:0]  rd_set = set_of(i_pc);
      wire  [TAG_W-1:0]  rd_tag = tag_of(i_pc);

      logic              hit_way [WAYS];
      logic              hit;
      logic [WAY_W-1:0]  hit_idx;
      logic [29: 0]      hit_target;
      bp_kind_e          hit_kind;
      logic [CTR_W-1:0]  hit_ctr;

      always_comb begin: lookup
        hit        = 1'b0;
        hit_idx    = '0;
        for (int w = 0; w < WAYS; w++) begin
          //! a tagless buffer checks nothing but the valid bit: it cannot tell
          //! an aliased address from the right one, which is the deal
          hit_way[w] = valid_q[rd_set][w]
                     & ((p_btb_tag_bits < 1) | (tag_q[rd_set][w] == rd_tag));
          if (hit_way[w] && !hit) begin
            hit     = 1'b1;
            hit_idx = WAY_W'(w);
          end
        end
        hit_target = target_q[rd_set][hit_idx];
        hit_kind   = kind_q  [rd_set][hit_idx];
        hit_ctr    = ctr_q   [rd_set][hit_idx];
      end

      //! An unconditionnal transfer is taken by definition; a conditionnal one
      //! is taken when its counter says so. With no counter at all every hit is
      //! predicted taken, and the buffer relies on allocation to hold only
      //! branches that were taken the last time they resolved.
      wire  direction = (hit_kind == bp_branch)
                      ? ((p_btb_ctr_bits < 1) ? 1'b1 : hit_ctr[CTR_W-1])
                      : 1'b1;

      assign o_hit    = hit & direction;
      assign o_target = {hit_target, 2'b00};
      assign o_kind   = hit_kind;

      /*******************************************************
        Update
      *******************************************************/

      wire  [SET_W-1:0]  wr_set = set_of(i_upd_pc);
      wire  [TAG_W-1:0]  wr_tag = tag_of(i_upd_pc);

      logic              upd_hit;
      logic [WAY_W-1:0]  upd_idx;

      always_comb begin: update_lookup
        upd_hit = 1'b0;
        upd_idx = '0;
        for (int w = 0; w < WAYS; w++) begin
          if (valid_q[wr_set][w]
              && ((p_btb_tag_bits < 1) | (tag_q[wr_set][w] == wr_tag))
              && !upd_hit) begin
            upd_hit = 1'b1;
            upd_idx = WAY_W'(w);
          end
        end
      end

      //! Which way an allocation displaces. Round-robin keeps one pointer per
      //! set and is nearly free; the pseudo-random policy shares a single LFSR
      //! across the whole buffer, which costs less than a pointer per set and
      //! avoids the pathological eviction cycles a pointer can fall into.
      logic [WAY_W-1:0] rr_q [SETS];
      logic [15: 0]     lfsr_q;
      wire  [WAY_W-1:0] victim = (p_btb_repl != 0) ? lfsr_q[WAY_W-1:0] : rr_q[wr_set];
      wire  [WAY_W-1:0] wr_idx = upd_hit ? upd_idx : victim;

      //! A conditionnal branch that resolves not taken does not deserve an
      //! entry it does not have: allocating one would only teach the buffer to
      //! predict taken next time. Everything else -- a taken branch, a jump, a
      //! call, a return -- is worth remembering the moment it is seen.
      wire  allocate = i_upd_valid & ~upd_hit & (i_upd_taken | (i_upd_kind != bp_branch));
      wire  refresh  = i_upd_valid & upd_hit;

      //! An entry whose counter has bottomed out is genuinely not worth its
      //! place: it predicts not-taken, so it is doing nothing but occupying a
      //! way another branch could use.
      wire  evict    = refresh & (i_upd_kind == bp_branch) & ~i_upd_taken
                     & ((p_btb_ctr_bits < 1) | (ctr_q[wr_set][upd_idx] == CTR_MIN));

      always_ff @(posedge i_clk) begin: update
        if (i_rst) begin
          for (int s = 0; s < SETS; s++) begin
            rr_q[s] <= '0;
            for (int w = 0; w < WAYS; w++) begin
              valid_q [s][w] <= 1'b0;
              tag_q   [s][w] <= '0;
              target_q[s][w] <= '0;
              kind_q  [s][w] <= bp_branch;
              ctr_q   [s][w] <= CTR_INIT;
            end
          end
          lfsr_q <= 16'hace1;
        end else begin
          //! a plain maximal-length shift register; it only ever has to be
          //! unpredictable enough that two branches do not evict each other in
          //! lockstep
          if (p_btb_repl != 0) begin
            lfsr_q <= {lfsr_q[14:0], lfsr_q[15] ^ lfsr_q[13] ^ lfsr_q[12] ^ lfsr_q[10]};
          end
          if (allocate) begin
            valid_q [wr_set][wr_idx] <= 1'b1;
            tag_q   [wr_set][wr_idx] <= wr_tag;
            target_q[wr_set][wr_idx] <= i_upd_target[31:2];
            kind_q  [wr_set][wr_idx] <= i_upd_kind;
            ctr_q   [wr_set][wr_idx] <= CTR_INIT;
            if (p_btb_repl == 0) begin
              rr_q[wr_set] <= rr_q[wr_set] + 1'b1;
            end
          end else if (refresh) begin
            //! the target is rewritten even on a hit: an indirect transfer that
            //! is not a return changes target from one execution to the next,
            //! and remembering the last one is the whole prediction
            valid_q [wr_set][upd_idx] <= ~evict;
            target_q[wr_set][upd_idx] <= i_upd_target[31:2];
            kind_q  [wr_set][upd_idx] <= i_upd_kind;
            if (p_btb_ctr_bits > 0) begin
              if (i_upd_taken) begin
                if (ctr_q[wr_set][upd_idx] != CTR_MAX) begin
                  ctr_q[wr_set][upd_idx] <= ctr_q[wr_set][upd_idx] + 1'b1;
                end
              end else begin
                if (ctr_q[wr_set][upd_idx] != CTR_MIN) begin
                  ctr_q[wr_set][upd_idx] <= ctr_q[wr_set][upd_idx] - 1'b1;
                end
              end
            end
          end
        end
      end
    end
  endgenerate

endmodule

`endif // __CPU_BTB__
