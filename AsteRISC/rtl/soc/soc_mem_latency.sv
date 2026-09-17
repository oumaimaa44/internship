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

//! Configurable access latency in front of a memory.
//!
//! The whole SoC answers in one cycle: `soc_sp_ram` never raises `o_busy`, so a
//! cache put in front of it can only ever be neutral or worse and there is
//! nothing to explore. This module is what gives the memory a cost: it holds
//! `o_busy` for a number of cycles before letting the request through, so a
//! line refill has something to amortise.
//!
//! The three latencies are separate because that is what tells the shape of the
//! memory. A burst oriented memory -- an SDRAM, a serial flash with a read
//! command -- pays a long opening latency and then streams; a slow but random
//! access memory pays the same price every time. A read whose word address is
//! the one right after the previous access is taken to continue a burst and
//! pays `p_burst_latency` instead of `p_read_latency`, which is exactly the
//! access pattern a line refill produces.
//!
//! With the three latencies at zero the module is a wire and behaves like the
//! memory alone, `o_busy` included.
//!
//! Protocol, the one `soc_sp_ram` already follows and the one the cores expect:
//! the master holds its request while `o_busy` is high; the cycle `o_busy` is
//! low the transfer is taken, and read data lands the cycle after.

`ifndef __SOC_MEM_LATENCY__
`define __SOC_MEM_LATENCY__

module soc_mem_latency #(
  parameter p_read_latency  = 0,  //! stall cycles before a random access read is taken
  parameter p_burst_latency = 0,  //! stall cycles before a read that continues a burst is taken
  parameter p_write_latency = 0   //! stall cycles before a write is taken
)(
  input  wire         i_clk,        //! global clock
  input  wire         i_rst,        //! global reset

  // master side
  input  wire  [31:2] i_addr,       //! address
  input  wire  [ 3:0] i_be,         //! write byte enable
  input  wire         i_wr_en,      //! write enable
  input  wire  [31:0] i_wr_data,    //! write data
  input  wire         i_rd_en,      //! read enable
  output wire  [31:0] o_rd_data,    //! read data
  output wire         o_busy,       //! busy
  output wire         o_ack,        //! transfer acknowledge

  // memory side
  output wire  [31:2] o_addr,       //! address
  output wire  [ 3:0] o_be,         //! write byte enable
  output wire         o_wr_en,      //! write enable
  output wire  [31:0] o_wr_data,    //! write data
  output wire         o_rd_en,      //! read enable
  input  wire  [31:0] i_rd_data,    //! read data
  input  wire         i_busy,       //! memory busy
  input  wire         i_ack         //! memory transfer acknowledge
);

  //! widest latency to count up to, and the counter that does it
  localparam int MAX_LAT = (p_read_latency  > p_burst_latency)
                         ? ((p_read_latency  > p_write_latency) ? p_read_latency  : p_write_latency)
                         : ((p_burst_latency > p_write_latency) ? p_burst_latency : p_write_latency);
  localparam int CNT_W   = (MAX_LAT < 2) ? 1 : $clog2(MAX_LAT + 1);

  wire req;
  assign req = i_rd_en | i_wr_en;

  //! read data always comes straight from the memory: the module delays when a
  //! request is taken, not when the answer comes back once it has been.
  assign o_rd_data = i_rd_data;

  if (MAX_LAT == 0) begin: no_latency

    assign o_addr    = i_addr;
    assign o_be      = i_be;
    assign o_wr_data = i_wr_data;
    assign o_wr_en   = i_wr_en;
    assign o_rd_en   = i_rd_en;
    assign o_busy    = i_busy;
    assign o_ack     = i_ack;

  end else begin: latency

    //! The request has to be captured, not merely held back.
    //!
    //! `cpu_fetch` drives `ibus_rd_en` for one cycle and `cpu_fsm` asserts
    //! `o_en_dmem_wr` in `st_execute` only, so by the time the stall has been
    //! served the request is no longer on the bus to be forwarded. What is held
    //! back is the moment the memory sees it, so what the master presented has
    //! to be kept here until then.

    logic [CNT_W-1:0] cnt;      //! stall cycles already served
    logic             busy_q;   //! a captured transaction is in flight
    logic [31:2]      a_q;
    logic [ 3:0]      be_q;
    logic [31:0]      d_q;
    logic             wr_q, rd_q;
    logic [CNT_W-1:0] target_q; //! stall this transaction has to serve
    logic [31:2]      last_addr;//! word address of the last taken access
    logic             last_vld;

    //! a read landing exactly on the word after the previous access continues a
    //! burst. This is the access pattern of a line refill, and of nothing else
    //! in this SoC.
    wire sequential;
    assign sequential = last_vld && (i_addr == (last_addr + 30'd1));

    logic [CNT_W-1:0] target;
    always_comb begin
      if (i_wr_en) begin
        target = CNT_W'(p_write_latency);
      end else if (sequential) begin
        target = CNT_W'(p_burst_latency);
      end else begin
        target = CNT_W'(p_read_latency);
      end
    end

    //! the captured request reaches the memory once its stall has been served
    wire pass, accepted, capture;
    assign pass     = busy_q && (cnt >= target_q);
    assign accepted = pass && !i_busy;
    //! A request that turns up while one is already in flight replaces it
    //! rather than being dropped.
    //!
    //! The cores do not gate `o_en_fetch` on `ibus_busy` -- they gate the state
    //! transition -- so a fetch is issued whether or not the bus can take it,
    //! and a fetch that had nowhere to go would simply be lost. They also leave
    //! the request asserted for one cycle past the transfer, which starts a
    //! transaction for an address that has already been served; letting the next
    //! request replace it is what stops that stale one from swallowing it.
    //!
    //! Only a change of address or of direction counts, never a change of data,
    //! so this stays a narrow comparison. The master that does hold its request
    //! across a stall -- `soc_cache`, all through a refill -- holds the same
    //! address while it does, and therefore never triggers a restart.
    wire changed;
    assign changed = (i_addr != a_q) || (i_wr_en != wr_q) || (i_rd_en != rd_q);
    assign capture = req && (!busy_q || changed);

    assign o_addr    = a_q;
    assign o_be      = be_q;
    assign o_wr_data = d_q;
    assign o_wr_en   = wr_q & pass;
    assign o_rd_en   = rd_q & pass;

    //! Low on the cycle the memory takes the transfer, so the word lands the
    //! cycle after -- exactly where a one cycle memory would have put it.
    //!
    //! `accepted` is about the transfer in flight, which is not necessarily the
    //! one the master is presenting: a request that arrives in the very cycle an
    //! older one is taken would otherwise see `busy` low and read back the older
    //! one's word. So a master presenting a request is told it is free only when
    //! the transfer being taken is its own.
    wire own_accept;
    assign own_accept = accepted & ~changed;

    assign o_busy    = req ? ~own_accept : (busy_q & ~accepted);
    assign o_ack     = own_accept & i_ack;

    always_ff @(posedge i_clk) begin
      if (i_rst) begin
        cnt       <= '0;
        busy_q    <= 1'b0;
        a_q       <= '0;
        be_q      <= '0;
        d_q       <= '0;
        wr_q      <= 1'b0;
        rd_q      <= 1'b0;
        target_q  <= '0;
        last_addr <= '0;
        last_vld  <= 1'b0;
      end else begin
        if (accepted) begin
          last_addr <= a_q;
          last_vld  <= 1'b1;
        end
        if (capture) begin
          busy_q   <= 1'b1;
          cnt      <= '0;
          a_q      <= i_addr;
          be_q     <= i_be;
          d_q      <= i_wr_data;
          wr_q     <= i_wr_en;
          rd_q     <= i_rd_en;
          target_q <= target;
        end else if (accepted) begin
          busy_q   <= 1'b0;
        end else if (busy_q && (cnt < target_q)) begin
          cnt      <= cnt + CNT_W'(1);
        end
      end
    end

  end


endmodule

`endif // __SOC_MEM_LATENCY__
