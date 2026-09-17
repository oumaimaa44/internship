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

//! CPU instruction fetch stage (pipeline version)
//!
//! The fetch unit is a two-deep pipeline:
//!
//!   `fetch_addr_q` -> instruction memory (registered read) -> output
//!
//! so the instruction word presented on `o_instr` during cycle `c` is the one
//! addressed by `fetch_addr_q` during cycle `c-1`. `pc_q` shadows that address
//! so that `o_pc` always describes `o_instr`.
//!
//! Flow control is one enable, `i_en`, and one valid, `o_valid`, which together
//! make the stage an elastic buffer rather than a fixed two cycle shifter:
//!
//!  * `o_valid` says the bus holds a word this stage has fetched and not yet
//!    handed over. It is low out of reset, and low again whenever a word has
//!    been taken and the next one has not come back -- which the core turns
//!    straight into the validity of the IF slot, so a fetch still in flight
//!    becomes a bubble downstream without anything else having to know.
//!  * `i_en = 1` takes the word, if there is one.
//!  * a new read is presented unless a word is already waiting unconsumed, and
//!    the address register only moves when the bus takes the read. The same
//!    address therefore stays presented for as long as the bus refuses it,
//!    which is the protocol the memories expect, and the bus holds the previous
//!    word meanwhile.
//!
//! The distinction matters as soon as the instruction bus can stall, because
//! the word on the bus during a cycle belongs to the transfer taken during the
//! *previous* one: `ibus_busy` describes the fetch being issued, never the word
//! being delivered. Freezing the stage on `ibus_busy` would discard the word
//! that had just arrived; reporting it through `o_valid`, one transfer later,
//! is what puts the bubble in the right cycle.
//!
//! With a bus that never stalls a word is delivered every cycle the stage
//! advances, `o_valid` is high from the first fetch onwards, and the stage
//! behaves exactly like the fixed shifter it used to be.
//!
//! `i_redirect` is only sampled while the unit advances, and `o_advance` tells
//! the core when that happened so it can hold the target until then
//! (`p_redirect_buf`); without that register the control unit instead keeps the
//! resolving slots frozen while the bus stalls (see `cpu_hazard`).
//!
//! Front-end prediction (`p_btb_entries`, `p_ras_entries`) hangs off the address
//! register, and is the one thing that has to live here rather than in the
//! control unit: it predicts from an address, in the cycle that address is
//! handed to the memory, which is a cycle before the instruction at that address
//! exists anywhere in the core. A correctly predicted transfer therefore costs
//! nothing -- the target is fetched back to back with the branch, and no slot
//! downstream ever learns a control transfer happened. What the stage hands over
//! alongside the word is where it went (`o_predicted`, `o_predicted_pc`), so
//! that the slot resolving the transfer can check it.
//!
//! Everything else -- squashing wrong-path instructions, counting retired
//! instructions -- belongs to the control unit and to the write back stage, not
//! here.

`ifndef __CPU_FETCH_PIPE__
`define __CPU_FETCH_PIPE__

`ifdef VIVADO
 `include "packages/pck_control.sv"
 `include "packages/pck_isa.sv"
`else
 `include "core/packages/pck_control.sv"
 `include "core/packages/pck_isa.sv"
`endif

module cpu_fetch_pipe 
  import pck_control::*;
  import pck_isa::*;
#(
  parameter p_reset_vector = 32'hf0000000,

  //! front-end prediction (see `cpu_btb` and `cpu_ras`). `p_btb_entries = 0`
  //! removes both of them, and with them every gate added to this stage: the
  //! address register then advances by four or by a resolved target, which is
  //! exactly what it did before any of this existed.
  parameter p_btb_entries  = 0,           //! branch target buffer entries (0 = none)
  parameter p_btb_ways     = 1,           //! branch target buffer associativity
  parameter p_btb_tag_bits = 8,           //! address bits checked on a hit (0 = tagless)
  parameter p_btb_ctr_bits = 1,           //! per-entry direction counter (0 = always taken)
  parameter p_btb_repl     = 0,           //! replacement: 0 = round-robin, 1 = pseudo-random
  parameter p_ras_entries  = 0            //! return address stack depth (0 = none)
)(
  input  wire          i_clk,             //! global clock
  input  wire          i_rst,             //! global reset
  input  wire          i_sleep,           //! active high sleep control

  // instruction memory port
  output logic [31: 0] ibus_addr,         //! instruction bus address
  output logic [ 3: 0] ibus_be,           //! instruction bus write byte enable
  output logic         ibus_wr_en,        //! instruction bus write enable
  output logic [31: 0] ibus_wr_data,      //! instruction bus write data
  output logic         ibus_rd_en,        //! instruction bus read enable
  input  logic [31: 0] ibus_rd_data,      //! instruction bus read data
  input  logic         ibus_busy,         //! instruction bus busy
  input  logic         ibus_ack,          //! instruction bus transfer acknowledge

  // flow control
  input  wire          i_en,              //! take the word held on the output
  input  wire          i_redirect_req,    //! a target has resolved that has not reached this stage yet
  input  wire          i_redirect,        //! jump to `i_redirect_pc`
  input  wire  [31: 0] i_redirect_pc,     //! redirection target

  // front-end prediction update, when a control transfer resolves
  input  wire          i_upd_valid,       //! a control transfer resolved this cycle
  input  wire  [31: 0] i_upd_pc,          //! address of the instruction that resolved
  input  wire  [31: 0] i_upd_target,      //! the target it actually went to
  input  bp_kind_e     i_upd_kind,        //! what it actually was
  input  wire          i_upd_taken,       //! ...and whether it was taken

  // fetched instruction
  output logic         o_predicted,       //! the front-end left the sequential path after `o_instr`
  output logic [31: 0] o_predicted_pc,    //! ...and this is the address it went to
  output logic [31: 0] o_pc,              //! program counter of `o_instr`
  output logic [31: 0] o_pc_inc,          //! `o_pc` + 4
  output isa_instr_t   o_instr,           //! instruction word
  output logic         o_valid            //! `o_instr` holds a right-path word not yet taken
);

  logic [31: 0] fetch_addr_q;             //! address presented to the memory
  logic [31: 0] pc_q;                     //! address of the word on the output
  logic         valid_q;                  //! the output holds a word not yet taken

  //! the word on the output is handed over this cycle
  wire          consume  = i_en & valid_q;

  //! A read is presented unless a word is already waiting to be taken: fetching
  //! over it would replace the word on the bus before anyone has read it.
  wire          request  = ~i_sleep & (i_en | ~valid_q);

  //! the bus takes the read; the word lands on the next cycle
  wire          advance  = request & ~ibus_busy;

  /*******************************************************
    Redirection

    A redirection cannot always be acted upon in the cycle it is presented: the
    bus may be refusing the read that would carry it. The target is therefore
    latched until the address register does move. Nothing else in the core has
    to know, which is what keeps the instruction bus stall out of the control
    unit -- and out of the combinational loop it would otherwise close, since
    `ibus_busy` is produced by the very read the enable would gate.
  *******************************************************/

  logic         redirect_q;               //! a target has been resolved and not taken yet
  logic [31: 0] redirect_pc_q;

  wire          redirect_now = i_redirect | redirect_q;
  wire  [31: 0] redirect_pc  = i_redirect ? i_redirect_pc : redirect_pc_q;

  /*******************************************************
    Wrong path

    After a control transfer resolves, the front-end keeps delivering words
    fetched from the path it abandoned, until the target has been read out of
    the instruction memory. Those words are tagged here rather than counted
    outside, because how many of them there are is not a static property once
    the bus can stall: a read that is never taken produces no wrong-path word,
    and a target that waits for the bus produces more of them.

    Two bits are enough, and they simply travel with the two stages of the
    fetch: one for the address being presented, one for the word on the output.
  *******************************************************/

  logic         wrong_addr_q;             //! the address presented is on the abandoned path
  logic         wrong_out_q;              //! the word on the output is on the abandoned path

  //! Where the front-end went after the word on the output. It travels with the
  //! second fetch stage for the same reason the wrong-path tag does: it is a
  //! property of a fetch, decided a cycle before the instruction it describes
  //! comes back from memory, and the slot that resolves the transfer has no
  //! other way of learning it.
  logic         pred_out_q;               //! the front-end left the sequential path after that word
  logic [31: 0] pred_pc_out_q;            //! ...and this is the address it went to

  //! The address currently presented is not on the path the core has settled on.
  //!
  //! That is true from the cycle a control transfer resolves -- `i_redirect_req`
  //! for one that has not reached this stage yet, `redirect_now` for one that
  //! has -- and stays true until the target is actually read, which is the
  //! `advance` that loads it below.
  wire          addr_stale = wrong_addr_q | i_redirect_req | redirect_now;

  /*******************************************************
    Front-end prediction (`p_btb_entries`, `p_ras_entries`)

    The buffer is read with the address being presented to the instruction
    memory this cycle, and its answer chooses the address presented the next
    one. A correctly predicted transfer therefore costs nothing at all: the
    target is fetched back to back with the branch, and no slot downstream ever
    learns that a control transfer happened.

    This is what the decode-stage predictors cannot do. They only see an
    instruction once it has come back from memory, so the earliest they can act
    is a redirection, and a redirection always costs every barrier between the
    fetch and the slot that issued it.

    Nothing here is trusted. The address a prediction sends the front-end to is
    carried alongside the instruction, and the slot that resolves the transfer
    compares it to where the instruction really goes; a stale entry, a tag
    collision, or an address that is not a branch at all comes back as an
    ordinary misprediction.
  *******************************************************/

  wire          btb_hit;
  wire  [31: 0] btb_target;
  bp_kind_e     btb_kind;
  wire          ras_valid;
  wire  [31: 0] ras_top;

  cpu_btb #(
    .p_btb_entries  ( p_btb_entries  ),
    .p_btb_ways     ( p_btb_ways     ),
    .p_btb_tag_bits ( p_btb_tag_bits ),
    .p_btb_ctr_bits ( p_btb_ctr_bits ),
    .p_btb_repl     ( p_btb_repl     )
  ) btb (
    .i_clk          ( i_clk          ),
    .i_rst          ( i_rst          ),
    .i_pc           ( fetch_addr_q   ),
    .o_hit          ( btb_hit        ),
    .o_target       ( btb_target     ),
    .o_kind         ( btb_kind       ),
    .i_upd_valid    ( i_upd_valid    ),
    .i_upd_pc       ( i_upd_pc       ),
    .i_upd_target   ( i_upd_target   ),
    .i_upd_kind     ( i_upd_kind     ),
    .i_upd_taken    ( i_upd_taken    )
  );

  //! a return is the one transfer whose target the buffer cannot hold: the
  //! stack knows it, the buffer only knows that this address *is* a return
  wire          is_ret = (p_ras_entries != 0) & btb_hit & (btb_kind == bp_ret);

  //! A prediction is only worth making on an address the core still cares
  //! about. Predicting on the wrong path would be harmless -- those words are
  //! killed downstream -- but it would push and pop the stack for instructions
  //! that never execute, which is the one part of the front-end state that a
  //! wrong path can genuinely damage.
  wire          predict = btb_hit & ~addr_stale;

  //! The stack is only believed when it holds something. An empty stack is not
  //! a reason to give up on the prediction: the buffer still remembers the
  //! target this return went to last time, which is right whenever the function
  //! is called from one place -- and a leaf called from one place is most of
  //! what a small program does.
  wire          use_ras = is_ret & ras_valid;

  wire  [31: 0] predict_pc = use_ras ? ras_top : btb_target;

  //! the prediction is only acted upon when the fetch actually moves on: while
  //! the bus refuses the read, the same address stays presented and the same
  //! prediction is simply made again next cycle
  wire          predict_taken = predict & advance;

  /*******************************************************
    Pushing a call

    A push is driven by the *resolved* call, not by the predicted one, and the
    asymmetry with the pop is deliberate.

    A push made at fetch time can only happen on a call the buffer has already
    learned, because until then nothing at this stage knows the instruction is a
    call at all. A cold or evicted call site would then push nothing, the stack
    would stay one frame short, and every return after it would be wrong -- not
    just the matching one. That is a systematic error, and it does not go away
    with a bigger buffer or a better direction predictor; it is simply the stack
    losing track. Measured on Dhrystone it cost more than the stack ever
    returned.

    Resolution sees every call, learned or not. The push then lands a few cycles
    after the call was fetched instead of in the same cycle, which only matters
    for a callee that returns within the pipeline depth -- and a function that
    short has no call overhead worth predicting.

    The pop stays at fetch, where it has to be: the point of the stack is to
    have the target ready before the return has been decoded.
  *******************************************************/

  cpu_ras #(
    .p_ras_entries ( p_ras_entries                          )
  ) ras (
    .i_clk         ( i_clk                                  ),
    .i_rst         ( i_rst                                  ),
    .i_push        ( i_upd_valid & (i_upd_kind == bp_call)  ),
    .i_push_pc     ( i_upd_pc + 32'd4                       ),
    .i_pop         ( predict_taken & use_ras                ),
    .o_valid       ( ras_valid                              ),
    .o_top         ( ras_top                                )
  );

  //! A resolved redirection always wins over a prediction: it is the verdict of
  //! an older instruction, and the prediction is about one the core has just
  //! been told to abandon.
  wire  [31: 0] next_addr = redirect_now ? redirect_pc
                          : predict      ? predict_pc
                          :                (fetch_addr_q + 32'd4);


  always_ff @(posedge i_clk) begin: fetch_pipeline
    if (i_rst) begin
      fetch_addr_q  <= p_reset_vector;
      pc_q          <= p_reset_vector - 32'd4;
      valid_q       <= 1'b0;
      redirect_q    <= 1'b0;
      redirect_pc_q <= p_reset_vector;
      wrong_addr_q  <= 1'b0;
      wrong_out_q   <= 1'b0;
      pred_out_q    <= 1'b0;
      pred_pc_out_q <= 32'd0;
    end else begin
      if (advance) begin
        fetch_addr_q <= next_addr;
        pc_q         <= fetch_addr_q;
        //! the word about to land comes from the address presented now, so it
        //! inherits that address's tag
        wrong_out_q  <= addr_stale;
        //! the prediction made on the address presented now describes the word
        //! that address is about to deliver
        pred_out_q    <= predict;
        pred_pc_out_q <= predict_pc;
        //! and the address that replaces it is the target itself when one is
        //! being taken -- which is where the wrong path ends, unless a further
        //! control transfer has resolved in the meantime and this target is
        //! already superseded
        wrong_addr_q <= redirect_now ? i_redirect_req : addr_stale;
      end else begin
        //! the address sitting here goes stale the moment a control transfer
        //! resolves, whether or not the bus lets the fetch move on. Missing that
        //! is what would let the last wrong-path word through once the target is
        //! finally read, since by then the redirection is long over.
        wrong_addr_q <= addr_stale;
      end
      //! a word arriving always wins over one being taken: the two happen in
      //! the same cycle at full speed, and the output stays valid throughout
      if (advance) begin
        valid_q <= 1'b1;
      end else if (consume) begin
        valid_q <= 1'b0;
      end
      if (i_redirect) begin
        redirect_q    <= ~advance;
        redirect_pc_q <= i_redirect_pc;
      end else if (advance) begin
        redirect_q    <= 1'b0;
      end
    end
  end

  // the instruction memory is mapped at `p_reset_vector`; the bus carries the
  // offset inside that region
  assign ibus_addr    = fetch_addr_q & ~p_reset_vector;
  assign ibus_be      = 4'b0000;
  assign ibus_wr_en   = 1'b0;
  assign ibus_wr_data = 32'd0;
  assign ibus_rd_en   = request;

  assign o_pc         = pc_q;
  assign o_pc_inc     = pc_q + 32'd4;
  assign o_instr.code = ibus_rd_data;
  //! a wrong-path word is never handed over: it is simply not valid
  assign o_valid      = valid_q & ~wrong_out_q;
  assign o_predicted    = pred_out_q;
  assign o_predicted_pc = pred_pc_out_q;

endmodule

`endif // __CPU_FETCH_PIPE__
