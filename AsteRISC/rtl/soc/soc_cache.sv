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

//! Configurable blocking cache, transparent on the `soc_sp_ram` protocol.
//!
//! It presents on its CPU side exactly the interface a memory presents -- the
//! one of `soc_sp_ram` -- and drives the same interface towards the memory it
//! stands in front of. Nothing in the cores knows it is there: they already
//! hold their request while `busy` is high (`cpu_fsm`, `cpu_hazard`), which is
//! all a miss needs.
//!
//!
//! WHERE THE CYCLES GO
//!
//! The tags are flip-flops read asynchronously, so the hit is known in the
//! request cycle and the data array is read that same cycle: **a hit costs
//! exactly what the memory alone used to cost**, request in one cycle and word
//! in the next, not a cycle more. What this buys in cycles it pays in the
//! critical path -- an address now goes through a tag comparison before it
//! reaches the array -- and that is the point: it is a term of the exploration,
//! not an accident. Tags in a synchronous array would have moved that cost from
//! the critical path to one stall cycle on *every* access, which is the wrong
//! trade at this size.
//!
//! A miss holds `busy` for the refill, then falls back to the lookup, which now
//! hits: one cycle more than the strictly necessary, uniformly, in exchange for
//! having a single path that serves the data.
//!
//!
//! THE AXES, AND WHICH END OF THE RANGE THEY REACH
//!
//!   p_size_pw2      total data size, log2 bytes. The tag, valid and dirty bits
//!                   sit on top of that and are flip-flops, so the small end of
//!                   the range is dominated by them, not by the data.
//!   p_line_pw2      line size, log2 bytes (3..6). Longer lines amortise the
//!                   memory opening latency over more words and shrink the tag
//!                   array, and waste bandwidth as soon as the locality is not
//!                   there.
//!   p_ways          1, 2 or 4. Direct mapped needs no way mux and no
//!                   replacement state; associativity buys back conflict misses
//!                   and puts a mux behind the tag comparison.
//!   p_repl          0 = LRU (true for two ways, tree pseudo LRU for four)
//!                   1 = pseudo random, one LFSR for the whole cache
//!                   2 = FIFO, a counter per set
//!                   Ignored when direct mapped, where it costs nothing.
//!   p_write_back    0 = write through, every store also goes to memory
//!                   1 = write back, a store marks the line dirty and the line
//!                       is written out when it is evicted. Costs a dirty bit
//!                       per line and an eviction path, saves the store traffic.
//!   p_write_alloc   0 = a store that misses goes straight to memory
//!                   1 = a store that misses refills the line first
//!   p_wbuf_depth    write through only: how many stores may be posted before
//!                   the core has to wait for the memory. 0 = none, the core
//!                   waits for every store.
//!   p_read_only     instruction cache: there is no store path at all, and the
//!                   whole write side disappears.
//!
//! The two useful corners: (p_size_pw2 = 8, p_line_pw2 = 3, p_ways = 1,
//! write through, no write buffer) is a couple hundred flip-flops of tag in
//! front of 256 bytes; (p_size_pw2 = 12, p_line_pw2 = 5, p_ways = 4, LRU,
//! write back + write allocate) is a cache that misses rarely and costs about
//! as much as the core.
//!
//!
//! WHAT IT DOES NOT DO
//!
//! One outstanding miss, no hit under miss, no prefetch: the front end has
//! nothing to do during a refill anyway as long as the cores are strictly in
//! order and single issue. The write buffer is drained before a refill rather
//! than snooped, so a store still in the buffer can never be read back stale.
//! There is no invalidation port: the memory behind is not written by anyone
//! else in this SoC.

`ifndef __SOC_CACHE__
`define __SOC_CACHE__

module soc_cache #(
  parameter p_mem_depth_pw2 = 11,             //! depth of the memory behind, log2 words: sets the tag width
  parameter p_addr_mask     = 32'hf0000000,   //! address mask of the memory behind
  parameter p_size_pw2      = 9,              //! cache data size, log2 bytes
  parameter p_line_pw2      = 4,              //! line size, log2 bytes (3..6)
  parameter p_ways          = 1,              //! associativity: 1, 2 or 4
  parameter p_repl          = 0,              //! replacement: 0 = LRU, 1 = pseudo random, 2 = FIFO
  parameter p_write_back    = 0,              //! 0 = write through, 1 = write back
  parameter p_write_alloc   = 0,              //! 0 = no write allocate, 1 = write allocate
  parameter p_wbuf_depth    = 0,              //! posted store buffer depth (write through only)
  parameter p_read_only     = 0               //! 1 = instruction cache, no store path
)(
  input  wire         i_clk,        //! global clock
  input  wire         i_rst,        //! global reset, active high, synchronous

  // cpu side, the interface of `soc_sp_ram`
  input  wire  [31:2] i_addr,       //! address
  input  wire  [ 3:0] i_be,         //! write byte enable
  input  wire         i_wr_en,      //! write enable
  input  wire  [31:0] i_wr_data,    //! write data
  input  wire         i_rd_en,      //! read enable
  output logic [31:0] o_rd_data,    //! read data
  output logic        o_busy,       //! busy
  output logic        o_ack,        //! transfer acknowledge

  // memory side
  output logic [31:2] o_addr,       //! address
  output logic [ 3:0] o_be,         //! write byte enable
  output logic        o_wr_en,      //! write enable
  output logic [31:0] o_wr_data,    //! write data
  output logic        o_rd_en,      //! read enable
  input  wire  [31:0] i_rd_data,    //! read data
  input  wire         i_busy,       //! memory busy
  input  wire         i_ack         //! memory transfer acknowledge
);

  /******************
      Geometry
  ******************/

  localparam int LINE_PW2 = p_line_pw2 - 2;                    //! words per line, log2
  localparam int LINE_W   = 1 << LINE_PW2;                     //! words per line
  localparam int WAY_PW2  = (p_ways == 4) ? 2 : ((p_ways == 2) ? 1 : 0);
  localparam int WAY_SEL  = (WAY_PW2 == 0) ? 1 : WAY_PW2;      //! width of a way index
  localparam int SET_PW2  = p_size_pw2 - p_line_pw2 - WAY_PW2; //! sets, log2
  localparam int N_SETS   = 1 << SET_PW2;
  localparam int ADDR_W   = p_mem_depth_pw2;                   //! word address bits behind the cache
  localparam int TAG_W    = ADDR_W - SET_PW2 - LINE_PW2;
  localparam int DATA_AW  = SET_PW2 + LINE_PW2;                //! word address inside one way
  localparam int CNT_W    = LINE_PW2 + 1;                      //! counts 0..LINE_W

  //! replacement state per set: one bit for two way LRU, three for the four way
  //! tree, a way index for FIFO, nothing at all for pseudo random.
  localparam int RPL_W    = (p_ways == 1)                 ? 1 :
                            ((p_repl == 0)                ? ((p_ways == 4) ? 3 : 1) :
                            ((p_repl == 2)                ? WAY_PW2 : 1));
  localparam bit RPL_SET  = (p_ways > 1) && (p_repl != 1); //! the state is per set
  localparam int LFSR_W   = 8;                             //! pseudo random generator width

  //! A store can never be refused, so there is always at least one posted
  //! entry: `cpu_fsm` offers `o_en_dmem_wr` for the single cycle of
  //! `st_execute` and then waits in `st_memory` with nothing on the bus, so a
  //! slave that answers "no room" to that cycle has lost the store. What
  //! `p_wbuf_depth` buys beyond the first entry is how many stores may be in
  //! flight before the core has to wait; 0 and 1 therefore describe the same
  //! hardware, the smallest write through there is.
  localparam int WBUF_N   = (p_wbuf_depth < 1) ? 1 : p_wbuf_depth;
  localparam int WBUF_W   = (WBUF_N < 2) ? 1 : $clog2(WBUF_N);
  localparam bit HAS_WBUF = (p_read_only == 0);
  localparam bit HAS_WR   = (p_read_only == 0);
  localparam bit HAS_DRT  = (p_read_only == 0) && (p_write_back != 0);

  initial begin
    assert(p_line_pw2 >= 3 && p_line_pw2 <= 6)
      else $error("soc_cache: \"p_line_pw2\" must be between 3 and 6 (8 to 64 byte lines).");
    assert(p_ways == 1 || p_ways == 2 || p_ways == 4)
      else $error("soc_cache: \"p_ways\" must be 1, 2 or 4.");
    assert(SET_PW2 >= 1)
      else $error("soc_cache: the geometry leaves less than two sets: raise \"p_size_pw2\" or lower \"p_line_pw2\" / \"p_ways\".");
    assert(TAG_W >= 1)
      else $error("soc_cache: the cache is as large as the memory behind it, there is no tag left to compare.");
    assert(p_read_only == 0 || (p_write_back == 0 && p_write_alloc == 0 && p_wbuf_depth == 0))
      else $error("soc_cache: \"p_read_only\" leaves no store path, so the write policy parameters must be left at 0.");
  end

  /******************
      Lookup
  ******************/

  wire [31:2]        masked_addr;
  wire [ADDR_W-1:0]  word_addr;
  wire [LINE_PW2-1:0] req_off;
  wire [SET_PW2-1:0]  req_set;
  wire [TAG_W-1:0]    req_tag;

  assign masked_addr = i_addr & ~p_addr_mask[31:2];
  assign word_addr   = masked_addr[ADDR_W+1:2];
  assign req_off     = word_addr[LINE_PW2-1:0];
  assign req_set     = word_addr[SET_PW2+LINE_PW2-1:LINE_PW2];
  assign req_tag     = word_addr[ADDR_W-1:SET_PW2+LINE_PW2];

  logic [TAG_W-1:0] tag_q [p_ways-1:0][N_SETS-1:0];
  logic             vld_q [p_ways-1:0][N_SETS-1:0];
  logic             drt_q [p_ways-1:0][N_SETS-1:0];

  logic [p_ways-1:0] hit_way;
  wire               hit;

  always_comb begin
    for (int w = 0; w < p_ways; w++) begin
      hit_way[w] = vld_q[w][req_set] && (tag_q[w][req_set] == req_tag);
    end
  end
  assign hit = |hit_way;

  //! index of the hit way, one hot to binary
  logic [WAY_SEL-1:0] hit_idx;
  always_comb begin
    hit_idx = '0;
    for (int w = 0; w < p_ways; w++) begin
      if (hit_way[w]) hit_idx = WAY_SEL'(w);
    end
  end

  /******************
     Replacement
  ******************/

  logic [RPL_W-1:0]   rpl_q [N_SETS-1:0];  //! per set state, unused when pseudo random
  logic [LFSR_W-1:0]  lfsr_q;              //! whole cache state, pseudo random only
  logic [WAY_SEL-1:0] rpl_way;             //! way the policy would pick
  logic [WAY_SEL-1:0] victim_way;          //! way actually picked, invalid ways first
  logic [WAY_SEL-1:0] inv_way;
  logic               inv_found;

  always_comb begin
    inv_way   = '0;
    inv_found = 1'b0;
    for (int w = p_ways-1; w >= 0; w--) begin
      if (!vld_q[w][req_set]) begin
        inv_way   = WAY_SEL'(w);
        inv_found = 1'b1;
      end
    end
  end

  if (p_ways == 1) begin: repl_direct
    assign rpl_way = 1'b0;
  end else if (p_repl == 1) begin: repl_random
    //! a single LFSR for the whole cache: the cheapest way to break a conflict
    //! pattern, and the one that costs no state per set.
    assign rpl_way = lfsr_q[WAY_SEL-1:0];
  end else if (p_repl == 2) begin: repl_fifo
    assign rpl_way = rpl_q[req_set];
  end else if (p_ways == 2) begin: repl_lru2
    //! true LRU: with two ways the least recently used one *is* the other one
    assign rpl_way = rpl_q[req_set][0];
  end else begin: repl_plru4
    //! tree pseudo LRU: bit 0 says which half was used last, bits 1 and 2 say
    //! which way inside each half.
    assign rpl_way = {rpl_q[req_set][0], rpl_q[req_set][0] ? rpl_q[req_set][2] : rpl_q[req_set][1]};
  end

  assign victim_way = inv_found ? inv_way : rpl_way;

  /******************
       Data array
  ******************/

  logic [DATA_AW-1:0] arr_addr;
  logic [ 3:0]        arr_be;
  logic [31:0]        arr_wr_data;
  logic [p_ways-1:0]  arr_wr_en;
  logic [p_ways-1:0]  arr_rd_en;
  logic [31:0]        arr_rd_data [p_ways-1:0];

  for (genvar w = 0; w < p_ways; w++) begin: data_array
    soc_cache_ram #(
      .p_depth_pw2  ( DATA_AW           )
    ) way (
      .i_clk        ( i_clk             ),
      .i_addr       ( arr_addr          ),
      .i_be         ( arr_be            ),
      .i_wr_en      ( arr_wr_en[w]      ),
      .i_wr_data    ( arr_wr_data       ),
      .i_rd_en      ( arr_rd_en[w]      ),
      .o_rd_data    ( arr_rd_data[w]    )
    );
  end

  /******************
     Read data path
  ******************/

  //! `soc_sp_ram` holds its read data until the next read, and the cores rely
  //! on it, so the way mux is followed by a hold register and bypassed in the
  //! cycle the word actually comes out of the array.
  logic               rd_pending_q;
  logic [WAY_SEL-1:0] rd_way_q;
  logic [31:0]        rd_hold_q;
  logic [31:0]        way_mux;

  assign way_mux = arr_rd_data[rd_way_q];

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      rd_hold_q <= 32'd0;
    end else if (rd_pending_q) begin
      rd_hold_q <= way_mux;
    end
  end

  assign o_rd_data = rd_pending_q ? way_mux : rd_hold_q;

  /******************
      Miss engine
  ******************/

  typedef enum logic [2:0] {
    ST_IDLE,   //! serving the CPU out of the arrays
    ST_DRAIN,  //! emptying the write buffer before a refill may read stale memory
    ST_EVICT,  //! writing a dirty victim line back
    ST_FILL,   //! reading the missing line in
    ST_REPLAY  //! reading the word that missed out of the line just brought in
  } state_e;

  state_e state, next_state;

  //! The request that missed, kept for the replay.
  //!
  //! The two buses do not hold their request the same way. The data side drives
  //! it combinationally and waits on `dbus_busy` with everything still asserted
  //! (`cpu_fsm`, `st_memory`), so it is still there when the line arrives. The
  //! instruction side does not: `cpu_fetch` registers the request, `ibus_rd_en`
  //! is one cycle wide, and the core then waits on `ibus_busy` expecting to find
  //! the word one cycle after it drops. So the address of a miss is kept here,
  //! and `ST_REPLAY` reads it out of the line once the line is in -- which is
  //! also what makes `o_rd_data` land exactly where both protocols look for it.
  logic [SET_PW2-1:0]  ms_set;
  logic [TAG_W-1:0]    ms_tag;
  logic [WAY_SEL-1:0]  ms_way;
  logic [TAG_W-1:0]    ms_vtag;   //! tag of the victim, the address it is written back to
  logic [LINE_PW2-1:0] ms_off;    //! word that was asked for inside the line
  logic                ms_rd;     //! the request that missed was a read
  logic                ms_wr;     //! the request that missed was a store
  logic [ 3:0]         ms_be;     //! byte enable of that store
  logic [31:0]         ms_wr_data;//! data of that store

  logic [CNT_W-1:0]    ev_rd_ptr, ev_wr_ptr;
  logic                ev_dv;     //! the array output holds the word `ev_wr_ptr`
  logic [CNT_W-1:0]    fl_ptr, fl_wr_ptr;
  logic                fl_dv;     //! the memory output holds the word `fl_wr_ptr`

  wire ev_issue_rd, ev_taken, ev_done;
  wire fl_issue_rd, fl_taken, fl_done;

  /******************
     Write buffer
  ******************/

  logic [31:2]        wbuf_addr [WBUF_N-1:0];
  logic [ 3:0]        wbuf_be   [WBUF_N-1:0];
  logic [31:0]        wbuf_data [WBUF_N-1:0];
  logic [WBUF_W:0]    wbuf_cnt;
  logic [WBUF_W-1:0]  wbuf_rd, wbuf_wr;
  wire                wbuf_full, wbuf_empty;
  logic               wbuf_push, wbuf_pop;

  assign wbuf_empty = (wbuf_cnt == '0);
  assign wbuf_full  = HAS_WBUF ? (wbuf_cnt == (WBUF_W+1)'(WBUF_N)) : 1'b1;

  /******************
      Request
  ******************/

  wire req, needs_fill, wr_to_mem, wr_hit;

  assign req        = i_rd_en | (HAS_WR ? i_wr_en : 1'b0);
  assign needs_fill = req && !hit && (i_rd_en || (HAS_WR && i_wr_en && (p_write_alloc != 0)));
  assign wr_hit     = HAS_WR && i_wr_en && hit;
  //! a store reaches the memory unless it is absorbed by a dirty line, or unless
  //! it is going to be replayed after a refill
  assign wr_to_mem  = HAS_WR && i_wr_en && !needs_fill && !(HAS_DRT && hit);

  //! the memory port is free for the write buffer whenever the miss engine is
  //! not using it. A store arriving in the same cycle goes into the buffer, not
  //! onto the port, so a stream of stores drains at one per cycle instead of
  //! filling the buffer and then stalling on every one of them.
  wire wbuf_drain_ok;
  assign wbuf_drain_ok = HAS_WBUF && !wbuf_empty && ((state == ST_DRAIN) || (state == ST_IDLE));

  /******************
        Control
  ******************/

  //! eviction: the array is read one word ahead of the memory write, and the
  //! next read is only issued once the current word has been taken, so the
  //! array output is never overwritten before it has been used.
  assign ev_taken    = (state == ST_EVICT) && ev_dv && !i_busy;
  assign ev_issue_rd = (state == ST_EVICT) && (ev_rd_ptr < CNT_W'(LINE_W)) && (!ev_dv || ev_taken);
  assign ev_done     = (state == ST_EVICT) && ev_taken && (ev_wr_ptr == CNT_W'(LINE_W-1));

  //! refill: the read is issued, the word lands the cycle after it is taken and
  //! goes straight into the array.
  assign fl_issue_rd = (state == ST_FILL) && (fl_ptr < CNT_W'(LINE_W));
  assign fl_taken    = fl_issue_rd && !i_busy;
  assign fl_done     = (state == ST_FILL) && fl_dv && (fl_wr_ptr == CNT_W'(LINE_W-1));

  always_comb begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (needs_fill) begin
          if (HAS_WBUF && !wbuf_empty)                 next_state = ST_DRAIN;
          else if (HAS_DRT && vld_q[victim_way][req_set] && drt_q[victim_way][req_set])
                                                       next_state = ST_EVICT;
          else                                         next_state = ST_FILL;
        end
      end
      ST_DRAIN: begin
        if (wbuf_empty || (wbuf_pop && (wbuf_cnt == (WBUF_W+1)'(1)))) begin
          if (HAS_DRT && vld_q[ms_way][ms_set] && drt_q[ms_way][ms_set]) next_state = ST_EVICT;
          else                                                          next_state = ST_FILL;
        end
      end
      ST_EVICT: begin
        if (ev_done) next_state = ST_FILL;
      end
      ST_FILL: begin
        if (fl_done) next_state = ST_REPLAY;
      end
      ST_REPLAY: begin
        next_state = ST_IDLE;
      end
      default: next_state = ST_IDLE;
    endcase
  end

  /******************
      Memory port
  ******************/

  always_comb begin
    o_addr    = 30'd0;
    o_be      = 4'b0000;
    o_wr_en   = 1'b0;
    o_wr_data = 32'd0;
    o_rd_en   = 1'b0;

    if (state == ST_EVICT) begin
      o_addr    = 30'(ADDR_W'({ms_vtag, ms_set, ev_wr_ptr[LINE_PW2-1:0]}));
      o_be      = 4'b1111;
      o_wr_en   = ev_dv;
      o_wr_data = arr_rd_data[ms_way];
    end else if (state == ST_FILL) begin
      o_addr    = 30'(ADDR_W'({ms_tag, ms_set, fl_ptr[LINE_PW2-1:0]}));
      o_rd_en   = fl_issue_rd;
    end else if (wbuf_drain_ok) begin
      o_addr    = wbuf_addr[wbuf_rd];
      o_be      = wbuf_be[wbuf_rd];
      o_wr_data = wbuf_data[wbuf_rd];
      o_wr_en   = 1'b1;
    end
  end

  assign wbuf_pop  = wbuf_drain_ok && !i_busy;
  assign wbuf_push = HAS_WBUF && !wbuf_full &&
                     (((state == ST_IDLE) && wr_to_mem) || replay_wr_mem);

  /******************
       CPU port
  ******************/

  //! A full write buffer says busy whether or not a store is being presented
  //! this cycle.
  //!
  //! `cpu_fsm` asserts `o_en_dmem_wr` in `st_execute` for one cycle and then
  //! waits in `st_memory` for `dbus_busy` to fall, so a store is offered once
  //! and never again: a slave that answers "full" to the cycle it is offered in
  //! has simply lost it. Holding busy while there is no room instead keeps the
  //! *previous* access waiting until a slot frees, and since only a store fills
  //! the buffer and the core issues them one at a time, the slot that frees is
  //! still there when the next store arrives.
  always_comb begin
    o_busy = 1'b0;
    if (state != ST_IDLE) begin
      o_busy = 1'b1;
    end else if (needs_fill) begin
      o_busy = 1'b1;
    end else if (HAS_WBUF) begin
      o_busy = wbuf_full;
    end
  end

  assign o_ack = req & ~o_busy;

  /******************
      Array port
  ******************/

  wire cpu_rd_ok, cpu_wr_ok, replay_rd, replay_wr, replay_wr_mem;
  assign cpu_rd_ok = (state == ST_IDLE) && i_rd_en && hit;
  assign replay_rd = (state == ST_REPLAY) && ms_rd;
  //! a store that missed is replayed too: `cpu_fsm` asserts `o_en_dmem_wr` in
  //! `st_execute` only -- "write as soon as possible" -- so by the time the line
  //! is in, the store is no longer on the bus to be served again.
  assign replay_wr     = (state == ST_REPLAY) && ms_wr;
  assign replay_wr_mem = replay_wr && !HAS_DRT;   //! write through: memory too
  assign cpu_wr_ok = (state == ST_IDLE) && wr_hit && !o_busy;

  always_comb begin
    arr_addr    = DATA_AW'({req_set, req_off});
    arr_be      = 4'b1111;
    arr_wr_data = 32'd0;
    arr_wr_en   = '0;
    arr_rd_en   = '0;

    if (state == ST_EVICT) begin
      arr_addr             = DATA_AW'({ms_set, ev_rd_ptr[LINE_PW2-1:0]});
      arr_rd_en[ms_way]    = ev_issue_rd;
    end else if (state == ST_FILL) begin
      arr_addr             = DATA_AW'({ms_set, fl_wr_ptr[LINE_PW2-1:0]});
      arr_wr_data          = i_rd_data;
      arr_wr_en[ms_way]    = fl_dv;
    end else if (state == ST_REPLAY) begin
      arr_addr             = DATA_AW'({ms_set, ms_off});
      arr_be               = ms_be;
      arr_wr_data          = ms_wr_data;
      arr_wr_en[ms_way]    = replay_wr;
      arr_rd_en[ms_way]    = ms_rd;
    end else begin
      if (cpu_wr_ok) begin
        arr_be             = i_be;
        arr_wr_data        = i_wr_data;
        arr_wr_en[hit_idx] = 1'b1;
      end else if (cpu_rd_ok) begin
        arr_rd_en[hit_idx] = 1'b1;
      end
    end
  end

  /******************
        State
  ******************/

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      state        <= ST_IDLE;
      rd_pending_q <= 1'b0;
      rd_way_q     <= '0;
      ev_rd_ptr    <= '0;
      ev_wr_ptr    <= '0;
      ev_dv        <= 1'b0;
      fl_ptr       <= '0;
      fl_wr_ptr    <= '0;
      fl_dv        <= 1'b0;
      ms_set       <= '0;
      ms_tag       <= '0;
      ms_way       <= '0;
      ms_vtag      <= '0;
      ms_off       <= '0;
      ms_rd        <= 1'b0;
      ms_wr        <= 1'b0;
      ms_be        <= 4'b0000;
      ms_wr_data   <= 32'd0;
      for (int w = 0; w < p_ways; w++) begin
        for (int s = 0; s < N_SETS; s++) begin
          vld_q[w][s] <= 1'b0;
          drt_q[w][s] <= 1'b0;
          tag_q[w][s] <= '0;
        end
      end
    end else begin
      state        <= next_state;
      rd_pending_q <= cpu_rd_ok | replay_rd;
      if (cpu_rd_ok)      rd_way_q <= hit_idx;
      else if (replay_rd) rd_way_q <= ms_way;

      if (wr_hit && HAS_DRT && !o_busy && (state == ST_IDLE)) begin
        drt_q[hit_idx][req_set] <= 1'b1;
      end
      if (replay_wr && HAS_DRT) begin
        drt_q[ms_way][ms_set] <= 1'b1;
      end

      case (state)
        ST_IDLE: begin
          if (needs_fill) begin
            ms_set    <= req_set;
            ms_tag    <= req_tag;
            ms_way    <= victim_way;
            ms_vtag   <= tag_q[victim_way][req_set];
            ms_off     <= req_off;
            ms_rd      <= i_rd_en;
            ms_wr      <= HAS_WR && i_wr_en;
            ms_be      <= i_be;
            ms_wr_data <= i_wr_data;
            ev_rd_ptr <= '0;
            ev_wr_ptr <= '0;
            ev_dv     <= 1'b0;
            fl_ptr    <= '0;
            fl_wr_ptr <= '0;
            fl_dv     <= 1'b0;
          end
        end

        ST_EVICT: begin
          if (ev_issue_rd) begin
            ev_rd_ptr <= ev_rd_ptr + CNT_W'(1);
            ev_dv     <= 1'b1;
          end else if (ev_taken) begin
            ev_dv     <= 1'b0;
          end
          if (ev_taken) ev_wr_ptr <= ev_wr_ptr + CNT_W'(1);
          if (ev_done)  drt_q[ms_way][ms_set] <= 1'b0;
        end

        ST_FILL: begin
          if (fl_taken) fl_ptr <= fl_ptr + CNT_W'(1);
          fl_dv <= fl_taken;
          if (fl_dv) fl_wr_ptr <= fl_wr_ptr + CNT_W'(1);
          if (fl_done) begin
            tag_q[ms_way][ms_set] <= ms_tag;
            vld_q[ms_way][ms_set] <= 1'b1;
            drt_q[ms_way][ms_set] <= 1'b0;
          end
        end

        default: ;
      endcase
    end
  end

  /******************
    Write buffer
  ******************/

  if (HAS_WBUF) begin: write_buffer
    always_ff @(posedge i_clk) begin
      if (i_rst) begin
        wbuf_cnt <= '0;
        wbuf_rd  <= '0;
        wbuf_wr  <= '0;
      end else begin
        if (wbuf_push) begin
          wbuf_addr[wbuf_wr] <= replay_wr_mem ? 30'(ADDR_W'({ms_tag, ms_set, ms_off})) : masked_addr;
          wbuf_be  [wbuf_wr] <= replay_wr_mem ? ms_be     : i_be;
          wbuf_data[wbuf_wr] <= replay_wr_mem ? ms_wr_data : i_wr_data;
          wbuf_wr            <= (wbuf_wr == WBUF_W'(WBUF_N-1)) ? '0 : wbuf_wr + WBUF_W'(1);
        end
        if (wbuf_pop) begin
          wbuf_rd <= (wbuf_rd == WBUF_W'(WBUF_N-1)) ? '0 : wbuf_rd + WBUF_W'(1);
        end
        case ({wbuf_push, wbuf_pop})
          2'b10:   wbuf_cnt <= wbuf_cnt + (WBUF_W+1)'(1);
          2'b01:   wbuf_cnt <= wbuf_cnt - (WBUF_W+1)'(1);
          default: wbuf_cnt <= wbuf_cnt;
        endcase
      end
    end
  end else begin: no_write_buffer
    always_comb begin
      wbuf_cnt  = '0;
      wbuf_rd   = '0;
      wbuf_wr   = '0;
      wbuf_addr[0] = 30'd0;
      wbuf_be  [0] = 4'b0000;
      wbuf_data[0] = 32'd0;
    end
  end


  /******************
   Replacement state
  ******************/

  //! The state is refreshed by a hit and by a fill. The two never fall in the
  //! same cycle -- a hit is served from `ST_IDLE`, a fill ends in `ST_FILL` --
  //! so one write port on the array is enough.
  wire               rpl_hit_upd, rpl_fill_upd;
  wire [WAY_SEL-1:0] rpl_upd_way;
  wire [SET_PW2-1:0] rpl_upd_set;

  assign rpl_hit_upd  = (state == ST_IDLE) && req && hit && !o_busy;
  assign rpl_fill_upd = fl_done;
  assign rpl_upd_way  = rpl_fill_upd ? ms_way : hit_idx;
  assign rpl_upd_set  = rpl_fill_upd ? ms_set : req_set;

  if ((p_ways > 1) && (p_repl == 1)) begin: repl_state_random
    //! one maximal length LFSR for the whole cache, stepped on every lookup so
    //! two addresses that conflict do not keep picking the same victim
    always_ff @(posedge i_clk) begin
      if (i_rst) begin
        lfsr_q <= LFSR_W'(8'hA5);
      end else if (req) begin
        lfsr_q <= {lfsr_q[LFSR_W-2:0],
                   lfsr_q[LFSR_W-1] ^ lfsr_q[LFSR_W-3] ^ lfsr_q[LFSR_W-4] ^ lfsr_q[LFSR_W-5]};
      end
    end
  end else begin: repl_state_no_random
    always_comb lfsr_q = '0;
  end

  if ((p_ways == 2) && (p_repl == 0)) begin: repl_state_lru2
    //! with two ways the least recently used one is simply the other one
    always_ff @(posedge i_clk) begin
      if (i_rst) begin
        for (int s = 0; s < N_SETS; s++) rpl_q[s] <= '0;
      end else if (rpl_hit_upd || rpl_fill_upd) begin
        rpl_q[rpl_upd_set][0] <= ~rpl_upd_way[0];
      end
    end

  end else if ((p_ways == 4) && (p_repl == 0)) begin: repl_state_plru4
    //! tree pseudo LRU: bit 0 points at the half to evict from, bits 1 and 2 at
    //! the way to evict inside each half. An access flips the pointers that lead
    //! to it, so they end up pointing away from what was just used.
    logic [2:0] cur, nxt;
    assign cur = rpl_q[rpl_upd_set];
    assign nxt = {rpl_upd_way[1] ? ~rpl_upd_way[0] : cur[2],
                  rpl_upd_way[1] ? cur[1] : ~rpl_upd_way[0],
                  ~rpl_upd_way[1]};
    always_ff @(posedge i_clk) begin
      if (i_rst) begin
        for (int s = 0; s < N_SETS; s++) rpl_q[s] <= '0;
      end else if (rpl_hit_upd || rpl_fill_upd) begin
        rpl_q[rpl_upd_set] <= nxt;
      end
    end

  end else if ((p_ways > 1) && (p_repl == 2)) begin: repl_state_fifo
    //! FIFO: a counter per set, stepped only when a line is brought in, so a
    //! hit costs nothing at all here
    always_ff @(posedge i_clk) begin
      if (i_rst) begin
        for (int s = 0; s < N_SETS; s++) rpl_q[s] <= '0;
      end else if (rpl_fill_upd) begin
        rpl_q[rpl_upd_set] <= rpl_q[rpl_upd_set] + RPL_W'(1);
      end
    end

  end else begin: repl_state_none
    //! direct mapped, or pseudo random: there is no per set state to keep
    always_comb begin
      for (int s = 0; s < N_SETS; s++) rpl_q[s] = '0;
    end
  end


endmodule

`endif // __SOC_CACHE__
