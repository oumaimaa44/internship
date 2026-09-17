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

//! CPU minimal SoC

`ifndef __SOC_MIN__
`define __SOC_MIN__

`ifdef VIVADO
  `include "soc_config.sv"
  `include "packages/pck_soc_control.sv"
  `include "packages/pck_memory_map.sv"
  `include "../core/packages/pck_mem_bus.sv"
`else
  `include "soc/soc_config.sv"
  `include "soc/packages/pck_soc_control.sv"
  `include "soc/packages/pck_memory_map.sv"
  `include "core/packages/pck_mem_bus.sv"
`endif
 
module soc_min 
  import pck_memory_map::*;
  import pck_soc_control::*;
#(
  parameter p_reset_vector    = 32'hf0000000,
  parameter p_imem_init       = "firmware/imem.hex",
  parameter p_dmem_init       = "firmware/dmem.hex",
  parameter p_num_gpios       = 24,
  parameter p_manufacturer_id = 12'h456,
  parameter p_product_id      = 8'h01,

  parameter p_imem_depth_pw2  = 11,
  parameter p_dmem_depth_pw2  = 10,

  //! Caches. Both are off by default, and off means absent: `soc_mem_port`
  //! instantiates nothing and the bus reaches the memory exactly as it did
  //! before caches existed. See `soc_cache` for what each axis costs and buys.
  parameter p_icache_en          = 0,        //! instruction cache present
  parameter p_icache_size_pw2    = 9,        //! instruction cache size, log2 bytes
  parameter p_icache_line_pw2    = 4,        //! instruction cache line size, log2 bytes (3..6)
  parameter p_icache_ways        = 1,        //! instruction cache associativity: 1, 2 or 4
  parameter p_icache_repl        = 0,        //! instruction cache replacement: 0 = LRU, 1 = pseudo random, 2 = FIFO

  parameter p_dcache_en          = 0,        //! data cache present
  parameter p_dcache_size_pw2    = 9,        //! data cache size, log2 bytes
  parameter p_dcache_line_pw2    = 4,        //! data cache line size, log2 bytes (3..6)
  parameter p_dcache_ways        = 1,        //! data cache associativity: 1, 2 or 4
  parameter p_dcache_repl        = 0,        //! data cache replacement: 0 = LRU, 1 = pseudo random, 2 = FIFO
  parameter p_dcache_write_back  = 0,        //! data cache: 0 = write through, 1 = write back
  parameter p_dcache_write_alloc = 0,        //! data cache: 0 = no write allocate, 1 = write allocate
  parameter p_dcache_wbuf_depth  = 0,        //! data cache: posted store buffer depth (write through only)

  //! What the memories cost to reach. All zero is the one cycle SRAM the SoC
  //! has always had; anything else is what gives a cache something to amortise.
  //! See `soc_mem_latency`.
  parameter p_imem_rd_latency    = 0,        //! stall cycles before a random access instruction read is taken
  parameter p_imem_burst_latency = 0,        //! stall cycles before an instruction read continuing a burst is taken
  parameter p_dmem_rd_latency    = 0,        //! stall cycles before a random access data read is taken
  parameter p_dmem_burst_latency = 0,        //! stall cycles before a data read continuing a burst is taken
  parameter p_dmem_wr_latency    = 0,        //! stall cycles before a data write is taken

  
  parameter p_ext_rvc         = 0,
  parameter p_ext_rve         = 0,
  parameter p_ext_rvm         = 0,
  parameter p_ext_rvzicsr     = 0,
  parameter p_ext_custom      = 1,

  parameter p_counters        = 0,           //! use counters (mcycle, minstret)

  parameter p_mul_fast        = 0,           //! fast mul
  parameter p_mul_1_cycle     = 0,           //! one cycle mul
  parameter p_alu_share_adder = 0,           //! share the adder between sub, slt, sltu and the comparators
  parameter p_alu_shift_bits  = 32,          //! bits shifted per cycle (1, 2, 4, 8, 16 or 32 = barrel)
  parameter p_early_jal       = 1,           //! resolve `jal` from the decoder instead of the RF slot
  parameter p_redirect_buf    = 1,           //! register the redirection target before the fetch stage
  parameter p_branch_stage    = 0,           //! branch resolution slot: 0 = RF, 1 = EX
  parameter p_fwd_ex          = 1,           //! bypass from the EX barriers
  parameter p_fwd_ma          = 1,           //! bypass from the MA barriers
  parameter p_fwd_wb          = 1,           //! bypass from the WB barriers
  parameter p_fwd_pw          = 1,           //! bypass from the pending register file write

  parameter p_pipeline        = 0,

  // pipeline settings:   
  parameter p_stage_IF        = 1,
  parameter p_stage_IC        = 0,
  parameter p_stage_ID        = 1,
  parameter p_stage_RF        = 0,
  parameter p_stage_EX        = 1,
  parameter p_stage_MA        = 1,
  parameter p_stage_WB        = 1,

  // non pipeline settings:   
  parameter p_branch_pred     = 0,           //! branch prediction scheme (see above)
  parameter p_bp_index_bits   = 5,           //! dynamic prediction: log2 of the number of counters
  parameter p_bp_ctr_bits     = 2,           //! dynamic prediction: width of a saturating counter
  parameter p_bp_ghr_bits     = 0,           //! dynamic prediction: global history bits (0 = bimodal)
  parameter p_fetch_buf       = 0,           //! add buffers to fetch stage output
  parameter p_decode_buf      = 0,           //! add buffers to decode stage outputs
  parameter p_rf_sp           = 0,           //! register file is a single port ram
  parameter p_rf_read_buf     = 0,           //! register file has synchronous read
  parameter p_mem_buf         = 0,           //! add buffers to mem stage inputs
  parameter p_wb_buf          = 0,           //! add buffers to write back stage inputs
  parameter p_overlap         = 0,           //! merge write back into execute (multi-cycle core only)
  parameter p_branch_buf      = 0,           //! add buffers to alu comp outputs (+1 cycle for conditionnal branches)
  
  parameter p_wait_for_ack    = 0            //! wait for data bus acknowledgement
)(
  // Clock
  input  wire                    i_xclk,              //! external clock
  input  wire                    i_pll_clk,           //! PLL clock
  input  wire                    i_pll_locked,        //! high when pll is locked
  output logic                   o_pll_vco_en,        //! 
  output logic                   o_pll_cp_en,         //! 
  output logic [ 3: 0]           o_pll_trim,          //! 
  output logic                   o_xtal_en,           //! XTAL enable
  output logic                   o_clk,               //! 

  // Reset
  input  wire                    i_xrst,              //! external reset
  output logic                   o_rst,               //! 
  input  wire                    i_por,               //! POR (Power On Reset)
  
  // Power
  output logic                   o_regulator_en,      //! power regulator enable

  // Memory buses
  //mem_bus.cpu_side               dbus,                //! data bus
  //mem_bus.cpu_side               ibus,                //! instruction bus

  // Standalone SPI
  input  wire                    i_sck,               //! SPI clock
  input  wire                    i_sdi,               //! SPI data in
  output logic                   o_sdo,               //! SPI data out
  output logic                   o_sdo_en,            //! SPI data output enable
  input  wire                    i_csb,               //! SPI select

  // SPI flash memory
  output logic                   o_flash_clk,
  output logic                   o_flash_clk_out_en,
  output logic                   o_flash_csb,  
  output logic                   o_flash_csb_out_en,  
  input  wire                    i_flash_io0_din,
  input  wire                    i_flash_io1_din,
  input  wire                    i_flash_io2_din,
  input  wire                    i_flash_io3_din,
  output logic                   o_flash_io0_dout,
  output logic                   o_flash_io1_dout,
  output logic                   o_flash_io2_dout,
  output logic                   o_flash_io3_dout,
  output logic                   o_flash_io0_out_en,
  output logic                   o_flash_io1_out_en,
  output logic                   o_flash_io2_out_en,
  output logic                   o_flash_io3_out_en,

  // GPIO  
  input  wire  [p_num_gpios-1:0] i_gpio_in,         //! gpio read 
  output logic [p_num_gpios-1:0] o_gpio_out,        //! gpio write
  output logic [p_num_gpios-1:0] o_gpio_out_en,     //! gpio output enable
  output logic [p_num_gpios-1:0] o_gpio_pullup,     //! gpio pullup enable
  output logic [p_num_gpios-1:0] o_gpio_pulldown    //! gpio pulldown enable
);

  // data bus
  //mem_bus       dbus();
  logic [31:0] dbus_addr;       //! data bus address
  logic [ 3:0] dbus_be;         //! data bus write byte enable
  logic        dbus_wr_en;      //! data bus write enable
  logic [31:0] dbus_wr_data;    //! data bus write data
  logic        dbus_rd_en;      //! data bus read enable
  logic [31:0] dbus_rd_data;    //! data bus read data
  logic        dbus_busy;       //! data bus busy
  logic        dbus_ack;        //! data bus transfer acknowledge

  // instruction bus
  //mem_bus       ibus();
  logic [31:0] ibus_addr;       //! instruction bus address
  logic [ 3:0] ibus_be;         //! instruction bus write byte enable
  logic        ibus_wr_en;      //! instruction bus write enable
  logic [31:0] ibus_wr_data;    //! instruction bus write data
  logic        ibus_rd_en;      //! instruction bus read enable
  logic [31:0] ibus_rd_data;    //! instruction bus read data
  logic        ibus_busy;       //! instruction bus busy
  logic        ibus_ack;        //! instruction bus transfer acknowledge

  // bridge
  typedef enum integer {
    DMEM_ID,
    GPIO_ID,
    NUM_PERIPH,
    NO_PERIPH     
  } bridge_id_e;

  logic [31:0] br_base [NUM_PERIPH-1:0];
  assign br_base[DMEM_ID       ] = DMEM_ADDR;
  assign br_base[GPIO_ID       ] = GPIO_ADDR;

  logic [31:0] br_mask [NUM_PERIPH-1:0];
  assign br_mask[DMEM_ID       ] = DMEM_ADDR_MASK;
  assign br_mask[GPIO_ID       ] = GPIO_ADDR_MASK;

  logic [31:0] br_addr     [NUM_PERIPH-1:0];
  logic [ 3:0] br_be       [NUM_PERIPH-1:0];
  logic        br_wr_en    [NUM_PERIPH-1:0];
  logic [31:0] br_wr_data  [NUM_PERIPH-1:0];
  logic        br_rd_en    [NUM_PERIPH-1:0];
  logic [31:0] br_rd_data  [NUM_PERIPH-1:0];
  logic        br_busy     [NUM_PERIPH-1:0];
  logic        br_ack      [NUM_PERIPH-1:0];

  // CSR
  logic [63:0] mcycle;
  logic [63:0] mtime;

  // coprocessor
  logic [31: 0] alu_op_a;  
  logic [31: 0] alu_op_b;  
  logic [31: 0] copro_out0;
  logic [31: 0] copro_out1;
  logic [31: 0] copro_out2;
  logic [ 2: 0] copro_valid;

  /******************
          CLK
  ******************/

  logic        clk;

  assign clk = i_pll_clk;
  assign o_clk = clk;


  /******************
          RST
  ******************/

  logic        rst;

  assign rst = i_xrst | i_por;
  assign o_rst = rst;

  logic        sleep;
  assign sleep = ~i_pll_locked;


  //! Both cores support a stalling bus.
  //!
  //! The multi-cycle core waits in the state that issued the access; the
  //! pipelined core turns the two `busy` into a fetch freeze and an EX slot
  //! freeze in `cpu_hazard`, which the elastic pipeline turns into bubbles by
  //! itself. Both stalls fold away at elaboration when every slave answers in
  //! one cycle, so a configuration with neither cache nor latency is exactly
  //! the design that existed before any of this.

  /******************
        CPU CORE
  ******************/

  if (p_pipeline) begin: pipe
    `KEEP_HIERARCHY
    cpu_core_pipe #(
      .p_reset_vector ( p_reset_vector             ),
      .p_ext_rvc      ( p_ext_rvc                  ),
      .p_ext_rve      ( p_ext_rve                  ),
      .p_ext_rvm      ( p_ext_rvm                  ),
      .p_ext_rvzicsr  ( p_ext_rvzicsr              ),
      .p_ext_custom   ( p_ext_custom               ),
      .p_counters     ( p_counters                 ),
      .p_mul_fast     ( p_mul_fast                 ),
      .p_mul_1_cycle  ( p_mul_1_cycle              ),
      .p_alu_share_adder ( p_alu_share_adder       ),
      .p_alu_shift_bits  ( p_alu_shift_bits        ),
      .p_early_jal    ( p_early_jal                ),
      .p_redirect_buf ( p_redirect_buf             ),
      .p_branch_stage ( p_branch_stage             ),
      .p_fwd_ex       ( p_fwd_ex                   ),
      .p_fwd_ma       ( p_fwd_ma                   ),
      .p_fwd_wb       ( p_fwd_wb                   ),
      .p_fwd_pw       ( p_fwd_pw                   ),
      .p_branch_pred  ( p_branch_pred             ),
      .p_bp_index_bits( p_bp_index_bits           ),
      .p_bp_ctr_bits  ( p_bp_ctr_bits             ),
      .p_bp_ghr_bits  ( p_bp_ghr_bits             ),
      .p_stage_IF     ( p_stage_IF                 ),
      .p_stage_IC     ( p_stage_IC                 ),
      .p_stage_ID     ( p_stage_ID                 ),
      .p_stage_RF     ( p_stage_RF                 ),
      .p_stage_EX     ( p_stage_EX                 ),
      .p_stage_MA     ( p_stage_MA                 ),
      .p_stage_WB     ( p_stage_WB                 ),
      .p_fetch_buf    ( p_fetch_buf                ),
      .p_decode_buf   ( p_decode_buf               ),
      .p_rf_sp        ( p_rf_sp                    ),
      .p_rf_read_buf  ( p_rf_read_buf              ),
      .p_branch_buf   ( p_branch_buf               ),
      .p_mem_buf      ( p_mem_buf                  ),
      .p_wb_buf       ( p_wb_buf                   ),
      .p_wait_for_ack ( p_wait_for_ack             )
    ) cpu (
      .i_clk          ( clk                        ),
      .i_rst          ( rst                        ),
      .i_sleep        ( sleep                      ),
      .i_mcycle       ( mcycle                     ),
      .i_mtime        ( mtime                      ),
      .ibus_addr      ( ibus_addr                  ),
      .ibus_be        ( ibus_be                    ),
      .ibus_wr_en     ( ibus_wr_en                 ),
      .ibus_wr_data   ( ibus_wr_data               ),
      .ibus_rd_en     ( ibus_rd_en                 ),
      .ibus_rd_data   ( ibus_rd_data               ),
      .ibus_busy      ( ibus_busy                  ),
      .ibus_ack       ( ibus_ack                   ),
      .dbus_addr      ( dbus_addr                  ),
      .dbus_be        ( dbus_be                    ),
      .dbus_wr_en     ( dbus_wr_en                 ),
      .dbus_wr_data   ( dbus_wr_data               ),
      .dbus_rd_en     ( dbus_rd_en                 ),
      .dbus_rd_data   ( dbus_rd_data               ),
      .dbus_busy      ( dbus_busy                  ),
      .dbus_ack       ( dbus_ack                   ),
      .o_alu_op_a     ( alu_op_a                   ),
      .o_alu_op_b     ( alu_op_b                   ),
      .i_copro_out0   ( copro_out0                 ),
      .i_copro_out1   ( copro_out1                 ),
      .i_copro_out2   ( copro_out2                 ),
      .i_copro_valid  ( copro_valid                )
    );

  end else begin: nonpipe
    `KEEP_HIERARCHY
    cpu_core #(
      .p_reset_vector ( p_reset_vector             ),
      .p_ext_rvc      ( p_ext_rvc                  ),
      .p_ext_rve      ( p_ext_rve                  ),
      .p_ext_rvm      ( p_ext_rvm                  ),
      .p_ext_rvzicsr  ( p_ext_rvzicsr              ),
      .p_ext_custom   ( p_ext_custom               ),
      .p_counters     ( p_counters                 ),
      .p_mul_fast     ( p_mul_fast                 ),
      .p_mul_1_cycle  ( p_mul_1_cycle              ),
      .p_alu_share_adder ( p_alu_share_adder       ),
      .p_alu_shift_bits  ( p_alu_shift_bits        ),
      .p_branch_pred  ( p_branch_pred             ),
      .p_bp_index_bits( p_bp_index_bits           ),
      .p_bp_ctr_bits  ( p_bp_ctr_bits             ),
      .p_bp_ghr_bits  ( p_bp_ghr_bits             ),
      .p_fetch_buf    ( p_fetch_buf                ),
      .p_decode_buf   ( p_decode_buf               ),
      .p_rf_sp        ( p_rf_sp                    ),
      .p_rf_read_buf  ( p_rf_read_buf              ),
      .p_branch_buf   ( p_branch_buf               ),
      .p_mem_buf      ( p_mem_buf                  ),
      .p_wb_buf       ( p_wb_buf                   ),
      .p_overlap      ( p_overlap                  ),
      .p_wait_for_ack ( p_wait_for_ack             )
    ) cpu (
      .i_clk          ( clk                        ),
      .i_rst          ( rst                        ),
      .i_sleep        ( sleep                      ),
      .i_mcycle       ( mcycle                     ),
      .i_mtime        ( mtime                      ),
      .ibus_addr      ( ibus_addr                  ),
      .ibus_be        ( ibus_be                    ),
      .ibus_wr_en     ( ibus_wr_en                 ),
      .ibus_wr_data   ( ibus_wr_data               ),
      .ibus_rd_en     ( ibus_rd_en                 ),
      .ibus_rd_data   ( ibus_rd_data               ),
      .ibus_busy      ( ibus_busy                  ),
      .ibus_ack       ( ibus_ack                   ),
      .dbus_addr      ( dbus_addr                  ),
      .dbus_be        ( dbus_be                    ),
      .dbus_wr_en     ( dbus_wr_en                 ),
      .dbus_wr_data   ( dbus_wr_data               ),
      .dbus_rd_en     ( dbus_rd_en                 ),
      .dbus_rd_data   ( dbus_rd_data               ),
      .dbus_busy      ( dbus_busy                  ),
      .dbus_ack       ( dbus_ack                   ),
      .o_alu_op_a     ( alu_op_a                   ),
      .o_alu_op_b     ( alu_op_b                   ),
      .i_copro_out0   ( copro_out0                 ),
      .i_copro_out1   ( copro_out1                 ),
      .i_copro_out2   ( copro_out2                 ),
      .i_copro_valid  ( copro_valid                )
    );
  end


  /******************
  Instruction Memory
  ******************/
        
  //! instruction cache and instruction memory latency, or plain wires
  logic [31:2] imem_addr;
  logic [ 3:0] imem_be;
  logic        imem_wr_en;
  logic [31:0] imem_wr_data;
  logic        imem_rd_en;
  logic [31:0] imem_rd_data;
  logic        imem_busy;
  logic        imem_ack;

  soc_mem_port #(
    .p_mem_depth_pw2     ( p_imem_depth_pw2      ),
    .p_addr_mask         ( IMEM_ADDR_MASK        ),
    .p_cache_en          ( p_icache_en           ),
    .p_cache_size_pw2    ( p_icache_size_pw2     ),
    .p_cache_line_pw2    ( p_icache_line_pw2     ),
    .p_cache_ways        ( p_icache_ways         ),
    .p_cache_repl        ( p_icache_repl         ),
    .p_cache_write_back  ( 0                     ),
    .p_cache_write_alloc ( 0                     ),
    .p_cache_wbuf_depth  ( 0                     ),
    .p_read_only         ( 1                     ),
    .p_read_latency      ( p_imem_rd_latency     ),
    .p_burst_latency     ( p_imem_burst_latency  ),
    .p_write_latency     ( 0                     )
  ) ibus_port (
    .i_clk          ( clk                        ),
    .i_rst          ( rst                        ),
    .i_addr         ( ibus_addr[31:2]            ),
    .i_be           ( ibus_be                    ),
    .i_wr_en        ( ibus_wr_en                 ),
    .i_wr_data      ( ibus_wr_data               ),
    .i_rd_en        ( ibus_rd_en                 ),
    .o_rd_data      ( ibus_rd_data               ),
    .o_busy         ( ibus_busy                  ),
    .o_ack          ( ibus_ack                   ),
    .o_addr         ( imem_addr                  ),
    .o_be           ( imem_be                    ),
    .o_wr_en        ( imem_wr_en                 ),
    .o_wr_data      ( imem_wr_data               ),
    .o_rd_en        ( imem_rd_en                 ),
    .i_rd_data      ( imem_rd_data               ),
    .i_busy         ( imem_busy                  ),
    .i_ack          ( imem_ack                   )
  );

  `KEEP_HIERARCHY
  wrap_ram_imem #(
    .p_addr_base    ( IMEM_ADDR                  ),
    .p_addr_mask    ( IMEM_ADDR_MASK             ),
    .p_init_file    ( p_imem_init                ),
    .p_init_val     ( 32'h00000003               ),
    .p_depth_pw2    ( p_imem_depth_pw2           )
  ) imem (
    .i_clk          ( clk                        ),
    .i_rst          ( rst                        ),
    .i_addr         ( imem_addr                  ),
    .i_be           ( imem_be                    ),
    .i_wr_en        ( imem_wr_en                 ),
    .i_wr_data      ( imem_wr_data               ),
    .i_rd_en        ( imem_rd_en                 ),
    .o_rd_data      ( imem_rd_data               ),
    .o_busy         ( imem_busy                  ),
    .o_ack          ( imem_ack                   ) 
  );


  /******************
      Data Memory
  ******************/

  //! Data cache and data memory latency, or plain wires.
  //!
  //! The port sits behind the bridge, on the data memory branch alone: what the
  //! cache sees is data memory traffic and nothing else, so the peripherals are
  //! never cached and stay coherent without a single bit of logic saying so.
  logic [31:2] dmem_addr;
  logic [ 3:0] dmem_be;
  logic        dmem_wr_en;
  logic [31:0] dmem_wr_data;
  logic        dmem_rd_en;
  logic [31:0] dmem_rd_data;
  logic        dmem_busy;
  logic        dmem_ack;

  soc_mem_port #(
    .p_mem_depth_pw2     ( p_dmem_depth_pw2      ),
    .p_addr_mask         ( DMEM_ADDR_MASK        ),
    .p_cache_en          ( p_dcache_en           ),
    .p_cache_size_pw2    ( p_dcache_size_pw2     ),
    .p_cache_line_pw2    ( p_dcache_line_pw2     ),
    .p_cache_ways        ( p_dcache_ways         ),
    .p_cache_repl        ( p_dcache_repl         ),
    .p_cache_write_back  ( p_dcache_write_back   ),
    .p_cache_write_alloc ( p_dcache_write_alloc  ),
    .p_cache_wbuf_depth  ( p_dcache_wbuf_depth   ),
    .p_read_only         ( 0                     ),
    .p_read_latency      ( p_dmem_rd_latency     ),
    .p_burst_latency     ( p_dmem_burst_latency  ),
    .p_write_latency     ( p_dmem_wr_latency     )
  ) dbus_port (
    .i_clk          ( clk                        ),
    .i_rst          ( rst                        ),
    .i_addr         ( br_addr    [DMEM_ID][31:2] ),
    .i_be           ( br_be      [DMEM_ID]       ),
    .i_wr_en        ( br_wr_en   [DMEM_ID]       ),
    .i_wr_data      ( br_wr_data [DMEM_ID]       ),
    .i_rd_en        ( br_rd_en   [DMEM_ID]       ),
    .o_rd_data      ( br_rd_data [DMEM_ID]       ),
    .o_busy         ( br_busy    [DMEM_ID]       ),
    .o_ack          ( br_ack     [DMEM_ID]       ),
    .o_addr         ( dmem_addr                  ),
    .o_be           ( dmem_be                    ),
    .o_wr_en        ( dmem_wr_en                 ),
    .o_wr_data      ( dmem_wr_data               ),
    .o_rd_en        ( dmem_rd_en                 ),
    .i_rd_data      ( dmem_rd_data               ),
    .i_busy         ( dmem_busy                  ),
    .i_ack          ( dmem_ack                   )
  );

  `KEEP_HIERARCHY
  wrap_ram_dmem #(
    .p_addr_base    ( DMEM_ADDR                  ),
    .p_addr_mask    ( DMEM_ADDR_MASK             ),
    .p_init_file    ( p_dmem_init                ),
    .p_init_val     ( 32'h00000000               ),
    .p_depth_pw2    ( p_dmem_depth_pw2           )
  ) dmem (
    .i_clk          ( clk                        ),
    .i_rst          ( rst                        ),
    .i_addr         ( dmem_addr                  ),
    .i_be           ( dmem_be                    ),
    .i_wr_en        ( dmem_wr_en                 ),
    .i_wr_data      ( dmem_wr_data               ),
    .i_rd_en        ( dmem_rd_en                 ),
    .o_rd_data      ( dmem_rd_data               ),
    .o_busy         ( dmem_busy                  ),
    .o_ack          ( dmem_ack                   ) 
  );


  /******************
    Data bus bridge
  ******************/

  `KEEP_HIERARCHY
  soc_bridge #(
    .p_num_masters  ( NUM_PERIPH                 )
  ) bridge (
    .i_clk          ( clk                        ),
    //.dbus           ( dbus                       ),
    .dbus_addr      ( dbus_addr                  ),
    .dbus_be        ( dbus_be                    ),
    .dbus_wr_en     ( dbus_wr_en                 ),
    .dbus_wr_data   ( dbus_wr_data               ),
    .dbus_rd_en     ( dbus_rd_en                 ),
    .dbus_rd_data   ( dbus_rd_data               ),
    .dbus_busy      ( dbus_busy                  ),
    .dbus_ack       ( dbus_ack                   ),
    .i_base         ( br_base                    ),
    .i_mask         ( br_mask                    ),
    .o_addr         ( br_addr                    ),
    .o_be           ( br_be                      ),
    .o_wr_en        ( br_wr_en                   ),
    .o_wr_data      ( br_wr_data                 ),
    .o_rd_en        ( br_rd_en                   ),
    .i_rd_data      ( br_rd_data                 ),
    .i_busy         ( br_busy                    ),
    .i_ack          ( br_ack                     ) 
  );


  /******************
         GPIO
  ******************/

  `KEEP_HIERARCHY
  perif_gpio #(
    .p_num_gpios    ( p_num_gpios                   )
  ) gpio (
    .i_clk          ( clk                           ),
    .i_rst          ( rst                           ),
    .i_addr         ( br_addr    [GPIO_ID][9:2]     ),
    .i_be           ( br_be      [GPIO_ID]          ),
    .i_wr_en        ( br_wr_en   [GPIO_ID]          ),
    .i_wr_data      ( br_wr_data [GPIO_ID]          ),
    .i_rd_en        ( br_rd_en   [GPIO_ID]          ),
    .o_rd_data      ( br_rd_data [GPIO_ID]          ),
    .o_busy         ( br_busy    [GPIO_ID]          ),
    .o_ack          ( br_ack     [GPIO_ID]          ),

    .i_gpio_in      ( i_gpio_in                     ),
    .o_gpio_out     ( o_gpio_out                    ),
    .o_gpio_out_en  ( o_gpio_out_en                 ),
    .o_gpio_pullup  ( o_gpio_pullup                 ),
    .o_gpio_pulldown( o_gpio_pulldown               )
  );

  
  /******************
      CRC module
  ******************/

  if (p_ext_custom) begin
    copro_crc_parallel #(
      .p_output_reg         ( 0                  )
    ) crc_coprocessor ( 
      .i_clk                ( clk                ),
      .i_rst                ( rst                ),
      .i_op_a               ( alu_op_a           ),
      .i_op_b               ( alu_op_b           ),
      .i_en                 ( 1'b1               ),
      .i_ready              ( 1'b1               ),
      .o_valid              (                    ),
      .o_out                ( copro_out0         )
    );
  end


  /******************
     Cycle Counter
  ******************/

  if (p_counters) begin
    soc_cycle_counter cycle_counter (
      .i_clk                ( clk                ),
      .i_rst                ( rst                ),
      .i_sleep              ( sleep              ),
      .o_mcycle             ( mcycle             )
    );
  end

endmodule

`endif // __SOC_MIN__
