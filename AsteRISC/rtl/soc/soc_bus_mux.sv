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

//! Single port 32-bit wide RAM with optional .hex init file for simulation


`ifndef __SOC_DMA__
`define __SOC_DMA__

/*verilator public_on*/
module soc_bus_mux #(
)(
  input  wire         i_sel_b,      //! 0: select a, 1: select b

  input  wire  [31:2] i_addr_a,     //! write address
  input  wire  [ 3:0] i_be_a,       //! write byte enable
  input  wire         i_wr_en_a,    //! write enable
  input  wire  [31:0] i_wr_data_a,  //! write data
  input  wire         i_rd_en_a,    //! read enable
  output wire  [31:0] o_rd_data_a,  //! read data

  input  wire  [31:2] i_addr_b,     //! write address
  input  wire  [ 3:0] i_be_b,       //! write byte enable
  input  wire         i_wr_en_b,    //! write enable
  input  wire  [31:0] i_wr_data_b,  //! write data
  input  wire         i_rd_en_b,    //! read enable
  output wire  [31:0] o_rd_data_b,  //! read data

  output wire  [31:2] o_addr,       //! write address
  output wire  [ 3:0] o_be,         //! write byte enable
  output wire         o_wr_en,      //! write enable
  output wire  [31:0] o_wr_data,    //! write data
  output wire         o_rd_en,      //! read enable
  input  wire  [31:0] i_rd_data     //! read data
);

  logic [31:2] addr;    
  logic [ 3:0] be;
  logic        wr_en; 
  logic [31:0] wr_data; 
  logic        rd_en; 
  logic [31:0] rd_data_a;
  logic [31:0] rd_data_b;

  always_comb begin
    if (i_sel_b) begin
      addr        = i_addr_b;
      be          = i_be_b;
      wr_en       = i_wr_en_b;
      wr_data     = i_wr_data_b;
      rd_en       = i_rd_en_b;
      rd_data_a   = 32'h00000000;
      rd_data_b   = i_rd_data;
    end else begin
      addr        = i_addr_a;
      be          = i_be_a;
      wr_en       = i_wr_en_a;
      wr_data     = i_wr_data_a;
      rd_en       = i_rd_en_a;
      rd_data_a   = i_rd_data;
      rd_data_b   = 32'h00000000;
    end
  end

  assign o_addr      = addr;
  assign o_be        = be;
  assign o_wr_en     = wr_en;
  assign o_wr_data   = wr_data;
  assign o_rd_en     = rd_en;
  assign o_rd_data_a = rd_data_a;
  assign o_rd_data_b = rd_data_b;

endmodule
/*verilator public_off*/

`endif // __SOC_DMA__