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

//! Single port, byte enabled, synchronous read 32-bit RAM used as the data
//! array of `soc_cache`.
//!
//! Same discipline as `soc_sp_ram`: the address is presented in one cycle and
//! the word comes out the next one, a write leaves the read output untouched.
//! It is kept separate from `soc_sp_ram` because a cache data array has no
//! address decoding and no initialisation file, and because the way arrays are
//! what a synthesis tool has to map onto block RAM or on a memory macro: giving
//! them a module of their own is what makes them recognisable in a report.

`ifndef __SOC_CACHE_RAM__
`define __SOC_CACHE_RAM__

module soc_cache_ram #(
  parameter p_depth_pw2 = 6   //! depth of the array in power of two (number of 32-bit words)
)(
  input  wire                    i_clk,      //! global clock
  input  wire  [p_depth_pw2-1:0] i_addr,     //! word address
  input  wire  [ 3:0]            i_be,       //! write byte enable
  input  wire                    i_wr_en,    //! write enable
  input  wire  [31:0]            i_wr_data,  //! write data
  input  wire                    i_rd_en,    //! read enable
  output wire  [31:0]            o_rd_data   //! read data, valid the cycle after the request
);

  logic [31:0] mem_content [0:2**p_depth_pw2-1];
  logic [31:0] rd_data;

  always_ff @(posedge i_clk) begin: access_port
    if (i_wr_en) begin
      if (i_be[0]) mem_content[i_addr][ 7: 0] <= i_wr_data[ 7: 0];
      if (i_be[1]) mem_content[i_addr][15: 8] <= i_wr_data[15: 8];
      if (i_be[2]) mem_content[i_addr][23:16] <= i_wr_data[23:16];
      if (i_be[3]) mem_content[i_addr][31:24] <= i_wr_data[31:24];
    end else if (i_rd_en) begin
      rd_data <= mem_content[i_addr];
    end
  end

  assign o_rd_data = rd_data;

endmodule

`endif // __SOC_CACHE_RAM__
