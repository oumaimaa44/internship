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
 
// Feel free to use your regfile implementations instead of the ones below 

`ifndef __REGFILE__
`define __REGFILE__

`ifdef VIVADO
  `include "../soc/soc_config.sv"
`else
  `include "soc/soc_config.sv"
`endif

module cpu_regfile #(
  parameter p_ext_rve      = 0,   //! use RV32E extension (reduces the integer register count to 16)
  parameter p_rf_sp        = 0,   //! register file is a single port ram
  parameter p_rf_read_buf  = 0,   //! register file has synchronous read
  parameter p_bypass       = 0    //! forward the pending write back to the read ports (see below)
)(
  input  logic        i_clk,      //! global clock
  input  logic        i_rst,      //! global reset
  output logic        o_busy,     //! regfile is busy
  output logic        o_addr_oob, //! address out of bounds

  input  logic        i_rd1_en,   //! regfile read enable for port 1 (used only if p_rf_sp = 1)
  input  logic [ 4:0] i_rd1_addr, //! regfile read address for port 1
  output logic [31:0] o_rd1_data, //! regfile read data for port 1

  input  logic        i_rd2_en,   //! regfile read enable for port 2 (used only if p_rf_sp = 1)
  input  logic [ 4:0] i_rd2_addr, //! regfile read address for port 2
  output logic [31:0] o_rd2_data, //! regfile read data for port 2

  input  logic        i_wr_en,    //! regfile write enable
  input  logic [ 4:0] i_wr_addr,  //! regfile write address
  input  logic [31:0] i_wr_data   //! regfile write data
);

  initial begin
    assert(!p_rf_sp || p_rf_read_buf) else $error("parameter \"p_rf_sp\" cannot be enabled if \"p_rf_read_buf\" is disabled: cannot read asynchronously through two ports on a single port RAM.");
    assert(!p_bypass || !p_rf_sp) else $error("parameter \"p_bypass\" cannot be enabled together with \"p_rf_sp\": the single port register file cannot serve a write and a read in the same cycle.");
  end

  //! raw read ports, before the optional bypass
  logic [31:0] rd1_data_raw;
  logic [31:0] rd2_data_raw;

  generate
    if (p_rf_sp) begin
      logic        rd1_en_saved;
      logic        rd2_en_saved;
      logic [ 4:0] rd_addr;
      logic [31:0] rd_data;

      // saved read enables
      always_ff @(posedge i_clk) begin
        rd1_en_saved <= i_rd1_en;
        rd2_en_saved <= i_rd2_en;
      end  

      // select read address 
      always_comb begin
        if (i_rd1_en) begin 
          rd_addr    = i_rd1_addr;
        end else if (i_rd2_en) begin
          rd_addr    = i_rd2_addr;
        end
      end

      // select read data
      always_comb begin
        if (rd1_en_saved) begin 
          rd1_data_raw = rd_data;
        end else if (rd2_en_saved) begin
          rd2_data_raw = rd_data;
        end
      end  
      
      // single port RAM regfile 
      `KEEP_HIERARCHY
      cpu_regfile_sync_1r1w #(
        .p_half_regfile   ( p_ext_rve       )
      ) regfile (
        .i_clk            ( i_clk           ),
        .i_rst            ( i_rst           ),
        .o_busy           ( o_busy          ),
        .o_addr_oob       ( o_addr_oob      ),
        .i_rd_addr        ( rd_addr         ),
        .o_rd_data        ( rd_data         ),
        .i_wr_en          ( i_wr_en         ),
        .i_wr_addr        ( i_wr_addr       ),
        .i_wr_data        ( i_wr_data       ) 
      );
    end else begin
      if (p_rf_read_buf) begin
        // dual port RAM regfile 
        `KEEP_HIERARCHY
        cpu_regfile_sync_2r1w #(
          .p_half_regfile ( p_ext_rve       )
        ) regfile (
          .i_clk          ( i_clk           ),
          .i_rst          ( i_rst           ),
          .o_busy         ( o_busy          ),
          .o_addr_oob     ( o_addr_oob      ),
          .i_rd1_addr     ( i_rd1_addr      ),
          .o_rd1_data     ( rd1_data_raw    ),
          .i_rd2_addr     ( i_rd2_addr      ),
          .o_rd2_data     ( rd2_data_raw    ),
          .i_wr_en        ( i_wr_en         ),
          .i_wr_addr      ( i_wr_addr       ),
          .i_wr_data      ( i_wr_data       ) 
        );
      end else begin
        // dual port asynchronous read regfile 
        `KEEP_HIERARCHY
        cpu_regfile_async_2r1w #(
          .p_half_regfile ( p_ext_rve       )
        ) regfile (
          .i_clk          ( i_clk           ),
          .i_rst          ( i_rst           ),
          .o_busy         ( o_busy          ),
          .o_addr_oob     ( o_addr_oob      ),
          .i_rd1_addr     ( i_rd1_addr      ),
          .o_rd1_data     ( rd1_data_raw    ),
          .i_rd2_addr     ( i_rd2_addr      ),
          .o_rd2_data     ( rd2_data_raw    ),
          .i_wr_en        ( i_wr_en         ),
          .i_wr_addr      ( i_wr_addr       ),
          .i_wr_data      ( i_wr_data       ) 
        );
      end
    end
  endgenerate

  //! Write back bypass.
  //!
  //! Only useful with `p_overlap`: the merged write back means instruction `i`
  //! and instruction `i+1` are one cycle apart, so any buffer on the write path
  //! (`p_wb_buf`) makes the write land after the read that needs it. The bypass
  //! is a single depth-1 forward -- there is no deeper hazard to cover, because
  //! `i+2` always finds the value already in the array.
  //!
  //! Two timings, depending on how the read port is built:
  //!
  //!  - asynchronous read (`p_rf_read_buf = 0`): `i+1` reads combinationally
  //!    during the very cycle the pending write is presented to the array, so
  //!    the comparison and the mux are both combinational.
  //!  - synchronous read (`p_rf_read_buf = 1`): the array samples the read
  //!    address on the same edge that commits the write, and it is read-first,
  //!    so the stale value comes out one cycle later. The hit is therefore
  //!    computed on the read address *being sampled* and consumed one cycle
  //!    later, together with a registered copy of the write data.
  //!
  //! Note that `x0` is excluded on the write side, exactly as the arrays do.
  generate
    if (p_bypass) begin: gen_bypass
      wire hit1 = i_wr_en && (i_wr_addr != 5'd0) && (i_wr_addr == i_rd1_addr);
      wire hit2 = i_wr_en && (i_wr_addr != 5'd0) && (i_wr_addr == i_rd2_addr);

      if (p_rf_read_buf) begin: gen_bypass_sync
        logic        hit1_buf;
        logic        hit2_buf;
        logic [31:0] wr_data_buf;

        always_ff @(posedge i_clk) begin: bypass_buf
          if (i_rst) begin
            hit1_buf <= 1'b0;
            hit2_buf <= 1'b0;
          end else begin
            hit1_buf <= hit1;
            hit2_buf <= hit2;
          end
          wr_data_buf <= i_wr_data;
        end

        always_comb begin: bypass_sync
          o_rd1_data = hit1_buf ? wr_data_buf : rd1_data_raw;
          o_rd2_data = hit2_buf ? wr_data_buf : rd2_data_raw;
        end
      end else begin: gen_bypass_async
        always_comb begin: bypass_async
          o_rd1_data = hit1 ? i_wr_data : rd1_data_raw;
          o_rd2_data = hit2 ? i_wr_data : rd2_data_raw;
        end
      end
    end else begin: gen_no_bypass
      always_comb begin: no_bypass
        o_rd1_data = rd1_data_raw;
        o_rd2_data = rd2_data_raw;
      end
    end
  endgenerate

endmodule

`endif // __REGFILE__
