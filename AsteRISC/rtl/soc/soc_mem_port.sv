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

//! What stands between a bus and the memory it addresses: an optional cache,
//! and an optional access latency for the memory behind it.
//!
//! It exists so that the instruction side and the data side, in `soc_min` and
//! in `soc_full`, all get the same thing from one place, and so that the two
//! options can be turned off without leaving anything behind. With
//! `p_cache_en = 0` and the three latencies at zero every signal here is a
//! wire: the generate blocks below instantiate nothing, and the netlist is the
//! one the SoC had before any of this existed. That is what makes the existing
//! configurations comparable to the new ones -- they are not "cache disabled",
//! they are the same hardware.
//!
//! Order matters: the cache is the master, the latency belongs to the memory.
//! Putting the latency behind the cache is what lets a refill amortise it, and
//! is what makes the two axes mean something together.

`ifdef VIVADO
  `include "soc_config.sv"
`else
  `include "soc/soc_config.sv"
`endif

`ifndef __SOC_MEM_PORT__
`define __SOC_MEM_PORT__

module soc_mem_port #(
  parameter p_mem_depth_pw2     = 11,           //! depth of the memory behind, log2 words
  parameter p_addr_mask         = 32'hf0000000, //! address mask of the memory behind

  // cache
  parameter p_cache_en          = 0,            //! 0 = the bus reaches the memory untouched
  parameter p_cache_size_pw2    = 9,            //! cache data size, log2 bytes
  parameter p_cache_line_pw2    = 4,            //! line size, log2 bytes (3..6)
  parameter p_cache_ways        = 1,            //! associativity: 1, 2 or 4
  parameter p_cache_repl        = 0,            //! replacement: 0 = LRU, 1 = pseudo random, 2 = FIFO
  parameter p_cache_write_back  = 0,            //! 0 = write through, 1 = write back
  parameter p_cache_write_alloc = 0,            //! 0 = no write allocate, 1 = write allocate
  parameter p_cache_wbuf_depth  = 0,            //! posted store buffer depth (write through only)
  parameter p_read_only         = 0,            //! 1 = instruction side, no store path

  // memory behind
  parameter p_read_latency      = 0,            //! stall cycles before a random access read is taken
  parameter p_burst_latency     = 0,            //! stall cycles before a read that continues a burst is taken
  parameter p_write_latency     = 0             //! stall cycles before a write is taken
)(
  input  wire         i_clk,        //! global clock
  input  wire         i_rst,        //! global reset

  // bus side
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

  //! between the cache and the latency
  wire [31:2] mid_addr;
  wire [ 3:0] mid_be;
  wire        mid_wr_en;
  wire [31:0] mid_wr_data;
  wire        mid_rd_en;
  wire [31:0] mid_rd_data;
  wire        mid_busy;
  wire        mid_ack;

  /******************
        Cache
  ******************/

  if (p_cache_en != 0) begin: cache

    `KEEP_HIERARCHY
    soc_cache #(
      .p_mem_depth_pw2  ( p_mem_depth_pw2      ),
      .p_addr_mask      ( p_addr_mask          ),
      .p_size_pw2       ( p_cache_size_pw2     ),
      .p_line_pw2       ( p_cache_line_pw2     ),
      .p_ways           ( p_cache_ways         ),
      .p_repl           ( p_cache_repl         ),
      .p_write_back     ( p_cache_write_back   ),
      .p_write_alloc    ( p_cache_write_alloc  ),
      .p_wbuf_depth     ( p_cache_wbuf_depth   ),
      .p_read_only      ( p_read_only          )
    ) cache (
      .i_clk            ( i_clk                ),
      .i_rst            ( i_rst                ),
      .i_addr           ( i_addr               ),
      .i_be             ( i_be                 ),
      .i_wr_en          ( i_wr_en              ),
      .i_wr_data        ( i_wr_data            ),
      .i_rd_en          ( i_rd_en              ),
      .o_rd_data        ( o_rd_data            ),
      .o_busy           ( o_busy               ),
      .o_ack            ( o_ack                ),
      .o_addr           ( mid_addr             ),
      .o_be             ( mid_be               ),
      .o_wr_en          ( mid_wr_en            ),
      .o_wr_data        ( mid_wr_data          ),
      .o_rd_en          ( mid_rd_en            ),
      .i_rd_data        ( mid_rd_data          ),
      .i_busy           ( mid_busy             ),
      .i_ack            ( mid_ack              )
    );

  end else begin: no_cache

    assign mid_addr    = i_addr;
    assign mid_be      = i_be;
    assign mid_wr_en   = i_wr_en;
    assign mid_wr_data = i_wr_data;
    assign mid_rd_en   = i_rd_en;
    assign o_rd_data   = mid_rd_data;
    assign o_busy      = mid_busy;
    assign o_ack       = mid_ack;

  end

  /******************
       Latency
  ******************/

  if ((p_read_latency != 0) || (p_burst_latency != 0) || (p_write_latency != 0)) begin: slow_memory

    `KEEP_HIERARCHY
    soc_mem_latency #(
      .p_read_latency   ( p_read_latency       ),
      .p_burst_latency  ( p_burst_latency      ),
      .p_write_latency  ( p_write_latency      )
    ) latency (
      .i_clk            ( i_clk                ),
      .i_rst            ( i_rst                ),
      .i_addr           ( mid_addr             ),
      .i_be             ( mid_be               ),
      .i_wr_en          ( mid_wr_en            ),
      .i_wr_data        ( mid_wr_data          ),
      .i_rd_en          ( mid_rd_en            ),
      .o_rd_data        ( mid_rd_data          ),
      .o_busy           ( mid_busy             ),
      .o_ack            ( mid_ack              ),
      .o_addr           ( o_addr               ),
      .o_be             ( o_be                 ),
      .o_wr_en          ( o_wr_en              ),
      .o_wr_data        ( o_wr_data            ),
      .o_rd_en          ( o_rd_en              ),
      .i_rd_data        ( i_rd_data            ),
      .i_busy           ( i_busy               ),
      .i_ack            ( i_ack                )
    );

  end else begin: fast_memory

    assign o_addr      = mid_addr;
    assign o_be        = mid_be;
    assign o_wr_en     = mid_wr_en;
    assign o_wr_data   = mid_wr_data;
    assign o_rd_en     = mid_rd_en;
    assign mid_rd_data = i_rd_data;
    assign mid_busy    = i_busy;
    assign mid_ack     = i_ack;

  end

endmodule

`endif // __SOC_MEM_PORT__
