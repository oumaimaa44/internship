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

`ifndef __SOC_TOP_WRAPPER__
`define __SOC_TOP_WRAPPER__

`ifdef VIVADO
  `include "soc_config.sv"
`else
  `include "soc/soc_config.sv"
`endif
 
module soc_wrapper_top #(
  /* verilator public_on*/

  // general settings
  parameter p_reset_vector    = 32'hf0000000,
  parameter p_num_gpios       = 24,

  // chip ids
  parameter p_manufacturer_id = 12'h456,
  parameter p_product_id      = 8'h01,

  
  //imem/dmem init files (simulations)
  parameter string p_imem_init = "/home/jsaussereau/Documents/bdxrcg/AsteRISC/AsteRISC-firmware/hex/dhrystone_benchmark_imem.hex",
  parameter string p_dmem_init = "/home/jsaussereau/Documents/bdxrcg/AsteRISC/AsteRISC-firmware/hex/dhrystone_benchmark_dmem.hex",
  
  // <sim_override> ------------------ 
  //imem/dmem detpth (power of two)
  // <mem>
  parameter p_imem_depth_pw2  = 14,          //! depth of the instruction memory in power of two (number of 32-bit words)
  parameter p_dmem_depth_pw2  = 13,          //! depth of the data memory in power of two (number of 32-bit words)
  // </mem>
  
  //RISC-V extensions
  
  parameter p_ext_rvzicsr     = 1,           //! use RV32Zicsr extension (control and status registers)
  parameter p_counters        = 1,           //! use counters (mcycle, minstret, mtime)
  // </sim_override> ------------------ 
  
  // <cache>
  //! Instruction and data caches. Both are off by default, and off means
  //! absent: `soc_mem_port` instantiates nothing, so a configuration with the
  //! caches off is not "the SoC with its caches disabled", it is the SoC as it
  //! was before they existed, down to the netlist. That is what keeps every
  //! result taken so far comparable with the ones taken from here on.
  //!
  //! Both cores take a bus that stalls. The multi-cycle core waits in the state
  //! that issued the access; the pipelined core has no state to wait in, so its
  //! fetch stage reports no word and its EX slot cannot move on, which the
  //! elastic pipeline turns into bubbles by itself.
  //!
  //! What each axis costs and buys is written in `soc_cache`; the short version:
  //!
  //!   p_?cache_size_pw2    total data size, log2 bytes. The tags are flip-flops
  //!                        and sit on top, so the small end of the range is
  //!                        dominated by them rather than by the data.
  //!   p_?cache_line_pw2    line size, log2 bytes, 3 to 6. Long lines amortise
  //!                        the memory opening latency and shrink the tag array,
  //!                        and waste bandwidth when the locality is not there.
  //!   p_?cache_ways        1, 2 or 4. Direct mapped needs neither a way mux nor
  //!                        replacement state; associativity buys back conflict
  //!                        misses and puts a mux behind the tag comparison.
  //!   p_?cache_repl        0 = LRU (true on two ways, tree pseudo LRU on four)
  //!                        1 = pseudo random, one LFSR for the whole cache
  //!                        2 = FIFO, a counter per set
  //!                        Free and ignored when direct mapped.
  //!
  //! And, on the data side only, the write policy -- which is where most of the
  //! area difference between the two ends of the range lives:
  //!
  //!   p_dcache_write_back  0 = write through, every store also reaches memory
  //!                        1 = write back, a store only marks the line dirty
  //!   p_dcache_write_alloc 0 = a store that misses goes straight to memory
  //!                        1 = a store that misses refills the line first
  //!   p_dcache_wbuf_depth  write through only: stores that may be posted before
  //!                        the core has to wait. 0 = the core waits for each one
  //!
  //! Two corners worth having in a sweep: (8, 3, 1, write through, no buffer) is
  //! a few hundred flip-flops of tag in front of 256 bytes; (12, 5, 4, LRU,
  //! write back + write allocate) misses rarely and costs about as much as the
  //! core it serves.
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
  // </cache>

  // <mem_latency>
  //! What the memories cost to reach.
  //!
  //! `soc_sp_ram` answers in one cycle and never raises `busy`, and with such a
  //! memory a cache can only ever be neutral or worse: there is nothing to
  //! amortise, so every point of the cache axes gives the same answer. These
  //! parameters are what gives the memory a price, and therefore what makes the
  //! cache axes measurable at all.
  //!
  //! A read landing on the word right after the previous access is taken to
  //! continue a burst and pays `burst` instead of `rd` -- which is exactly the
  //! access pattern of a line refill, and of nothing else in this SoC. A memory
  //! with a long opening and a fast stream (a serial flash, an SDRAM) is a large
  //! `rd` with a small `burst`; a slow but truly random access memory has the
  //! two equal.
  //!
  //! All zero is the one cycle SRAM the SoC has always had, and instantiates no
  //! logic at all.
  parameter p_imem_rd_latency    = 0,        //! stall cycles before a random access instruction read is taken
  parameter p_imem_burst_latency = 0,        //! stall cycles before an instruction read continuing a burst is taken
  parameter p_dmem_rd_latency    = 0,        //! stall cycles before a random access data read is taken
  parameter p_dmem_burst_latency = 0,        //! stall cycles before a data read continuing a burst is taken
  parameter p_dmem_wr_latency    = 0,        //! stall cycles before a data write is taken
  // </mem_latency>
  
  // <baseline>
  parameter p_ext_rve         = 0,           //! use RV32E extension (reduces the integer register count to 16)
  // </baseline>
  
  parameter p_ext_rvc         = 0,           //! use RV32C extension (compressed instructions)
  parameter p_ext_custom      = 0,           //! use custom extension

  // <mul>
  parameter p_ext_rvm         = 0,           //! use RV32M extension (multiplication and division)
  parameter p_mul_fast        = 0,           //! fast mul
  parameter p_mul_1_cycle     = 0,           //! one cycle mul
  // </mul>

  // <branch_pred>
  //! branch prediction scheme, shared by the multi-cycle and the pipelined cores:
  //!   0 = off     : no prediction, control transfers are resolved in the pipeline
  //!   1 = static  : backward taken / forward not taken, `jalr` never predicted
  //!   2 = dynamic : a table of saturating counters learns the direction of each
  //!                 conditionnal branch. `jal` is still always taken and `jalr`
  //!                 still never predicted -- only the direction is learned.
  //!
  //! The three parameters below shape the dynamic predictor, and they are what
  //! makes it span the whole range from "a handful of flip-flops" to "actually
  //! accurate". They are ignored when `p_branch_pred < 2`.
  //!
  //!   p_bp_index_bits : log2 of the number of counters (table size). The cost
  //!                     is 2**p_bp_index_bits * p_bp_ctr_bits flip-flops.
  //!   p_bp_ctr_bits   : 1 = remember the last outcome, no hysteresis
  //!                     2 = the classical bimodal counter, the usual sweet spot
  //!                     3+ = more inertia, rarely worth its area
  //!   p_bp_ghr_bits   : 0 = bimodal, the table is indexed by the pc alone
  //!                     n = gshare, the n last outcomes are xored into the
  //!                         index so a branch correlated with the ones before
  //!                         it gets its own counter per history pattern
  //!
  //! Two useful corners: (4, 1, 0) is a 16 flip-flop predictor that already
  //! catches loops; (9, 2, 6) is a 1 kib gshare that competes with much bigger
  //! cores. `p_bp_index_bits` is bounded by `BP_IDX_MAX` in `pck_pipe`.
  parameter p_branch_pred     = 0,           //! branch prediction scheme (see above)
  parameter p_bp_index_bits   = 5,           //! dynamic prediction: log2 of the number of counters
  parameter p_bp_ctr_bits     = 2,           //! dynamic prediction: width of a saturating counter
  parameter p_bp_ghr_bits     = 0,           //! dynamic prediction: global history bits (0 = bimodal)
  // </branch_pred>

  // <alu>
  //! ALU micro-architecture. Unlike `p_stage_*` and `p_*_buf`, which decide
  //! *where* the datapath is cut by a register barrier, these decide what
  //! stands between two barriers -- so they move the critical path without
  //! necessarily moving the cycle count. See `cpu_alu` for the details.
  //!
  //!   p_alu_share_adder : 0 = a dedicated operator per comparison and for the
  //!                           subtraction
  //!                       1 = sub, slt, sltu and the three branch comparators
  //!                           all read a single two's complement adder
  //!   p_alu_shift_bits  : bits shifted per cycle. 32 keeps the barrel shifter
  //!                       (five mux layers, one cycle); 1/2/4/8/16 replace it
  //!                       by a sequential shifter of log2(K)+1 layers costing
  //!                       up to 31/K extra cycles on shift instructions only.
  parameter p_alu_share_adder = 0,           //! share the adder between sub, slt, sltu and the comparators
  parameter p_alu_shift_bits  = 32,          //! bits shifted per cycle (1, 2, 4, 8, 16 or 32 = barrel)
  // </alu>

  // <pipe_ctrl>
  //! Pipelined core only: where a control transfer is acted upon.
  //!
  //!   p_branch_stage : 0 = the verdict redirects the front-end from the RF
  //!                        slot, the cycle it is produced
  //!                    1 = it is registered into the EX barrier first, which
  //!                        takes the redirection fan-out off the RF critical
  //!                        path and costs one extra bubble per redirection
  parameter p_early_jal       = 1,           //! resolve `jal` from the decoder instead of the RF slot
  parameter p_redirect_buf    = 1,           //! register the redirection target before the fetch stage
  parameter p_branch_stage    = 0,           //! branch resolution slot: 0 = RF, 1 = EX
  // </pipe_ctrl>

  // <fwd>
  //! Pipelined core only: which in-flight writes may be bypassed towards the
  //! ALU operands. Clearing one `p_fwd_*` drops that group from the bypass mux
  //! in front of the ALU and replaces it by a stall.
  parameter p_fwd_ex          = 1,           //! bypass from the EX barriers
  parameter p_fwd_ma          = 1,           //! bypass from the MA barriers
  parameter p_fwd_wb          = 1,           //! bypass from the WB barriers
  parameter p_fwd_pw          = 1,           //! bypass from the pending register file write
  // </fwd>

  // <main>
  parameter p_pipeline        = 0,           //! implement a pipepined architecure

  // pipeline settings:   
  parameter p_stage_IF        = 1,           //! use a register barrier after IF stage
  parameter p_stage_IC        = 0,           //! use a register barrier after IC stage
  parameter p_stage_ID        = 1,           //! use a register barrier after ID stage
  parameter p_stage_RF        = 0,           //! use a register barrier after RF stage
  parameter p_stage_EX        = 1,           //! use a register barrier after EX stage
  parameter p_stage_MA        = 1,           //! use a register barrier after MA stage
  parameter p_stage_WB        = 1,           //! use a register barrier after WB stage

  // multi-cycle settings:   
  parameter p_fetch_buf       = 0,           //! add buffers to fetch stage output
  parameter p_decode_buf      = 1,           //! add buffers to decode stage outputs
  parameter p_rf_sp           = 0,           //! register file is a single port ram
  parameter p_rf_read_buf     = 0,           //! register file has synchronous read
  parameter p_mem_buf         = 0,           //! add buffers to mem stage inputs
  parameter p_wb_buf          = 1,           //! add buffers to write back stage inputs
  parameter p_branch_buf      = 0,           //! add buffers to alu comp outputs (+1 cycle for conditionnal branches)
  // </main>

  // <overlap>
  //! Multi-cycle core only: fold the write back state into the execute state.
  //!
  //!   p_overlap : 0 = the instruction bus request is registered, so an
  //!                   instruction word requested during execute only lands two
  //!                   cycles later: the write back state doubles as the shadow
  //!                   of the instruction memory latency. Straight line CPI 2.
  //!               1 = the request is driven combinationally, the word lands the
  //!                   very next cycle, and the write back merges into execute.
  //!                   Straight line CPI 1; loads stay at 3 because they hold
  //!                   the data bus. In exchange the whole `imem read data ->
  //!                   decompress -> decode -> next pc` chain lands in front of
  //!                   the instruction memory address input.
  //!
  //! `p_wb_buf` and `p_rf_read_buf` stay usable: `cpu_regfile` carries a depth-1
  //! bypass that forwards the pending write back to the read ports, which makes
  //! `p_wb_buf` free in cycles here (it used to cost a whole state) while still
  //! shortening the critical path.
  //!
  //! Requires `p_fetch_buf`, `p_decode_buf`, `p_branch_buf` and `p_rf_sp` to be
  //! off. The first three are sequencing problems rather than data hazards: the
  //! extra state no longer falls in front of the cycle that consumes it. The
  //! last is structural: a single port register file cannot serve the merged
  //! write and the next read in the same cycle.
  parameter p_overlap         = 0,           //! merge write back into execute (see above)
  // </overlap>

  //implementation customization (not functionnal yet...)
  parameter p_imem_sram       = 1,            //! implement instruction memory in sram?
  parameter p_dmem_sram       = 1,            //! implement data memory in sram?
  parameter p_rf_sram         = 0,            //! implement regfile in sram? warning: 'p_rf_read_buf' must be '1'

  //security
  parameter p_wait_for_ack    = 0             //! wait for data bus acknowledgement. warning: gets stuck if addressing a non responding memory + reduces fax frequency when activated
  
  /* verilator public_off*/
)(
  // Global
  input  wire                   i_xtal_p,     //! Pin 13: XTAL positive
  input  wire                   i_xtal_n,     //! Pin 14: XTAL negative
  input  wire                   i_xclk,       //! Pin 28: External Clock
  input  wire                   i_xrst,       //! Pin 29: External Reset

  // Standalone SPI
  input  wire                   i_sck,        //! Pin 18: SPI Clock
  input  wire                   i_csb,        //! Pin 17: SPI Chip Select
  input  wire                   i_sdi,        //! Pin 16: SPI Data In
  output wire                   o_sdo,        //! Pin 15: SPI Data Out

  // QSPI flash
  output wire                   o_flash_clk,  //! Pin 21: QSPI Clock
  output wire                   o_flash_csb,  //! Pin 22: QSPI Chip Select
  inout  wire                   io_flash0,    //! Pin 23: QSPI Bidirectionnal Data IO 0
  inout  wire                   io_flash1,    //! Pin 24: QSPI Bidirectionnal Data IO 1
  inout  wire                   io_flash2,    //! Pin 25: QSPI Bidirectionnal Data IO 2
  inout  wire                   io_flash3,    //! Pin 26: QSPI Bidirectionnal Data IO 3

  // GPIOs
  inout  wire [p_num_gpios-1:0] io_gpio       //! General Purpose IOs
);


// Clock
wire                    w_i_xclk;
wire                    w_i_pll_clk;
wire                    w_i_pll_locked;
wire                    w_o_clk;
wire                    w_o_rst;
wire                    w_o_xtal_en;
wire                    w_o_pll_vco_en;
wire                    w_o_pll_cp_en;
wire  [ 3: 0]           w_o_pll_trim;
wire                    w_i_xtal_p;
wire                    w_i_xtal_n;

// Reset
wire                    w_i_xrst;
wire                    w_i_por;

// Power 
wire                    w_o_regulator_en;

// SPI
wire                    w_i_sck;
wire                    w_i_sdi;
wire                    w_o_sdo;
wire                    w_o_sdo_en;
wire                    w_i_csb;

// QSPI FLASH   
wire                    w_o_flash_clk;
wire                    w_o_flash_clk_out_en;
wire                    w_o_flash_csb;
wire                    w_o_flash_csb_out_en; 
wire                    w_i_flash_io0_din;
wire                    w_i_flash_io1_din;
wire                    w_i_flash_io2_din;
wire                    w_i_flash_io3_din;
wire                    w_o_flash_io0_dout;
wire                    w_o_flash_io1_dout;
wire                    w_o_flash_io2_dout;
wire                    w_o_flash_io3_dout;
wire                    w_o_flash_io0_out_en;
wire                    w_o_flash_io1_out_en;
wire                    w_o_flash_io2_out_en;
wire                    w_o_flash_io3_out_en;

// GPIOs
wire  [p_num_gpios-1:0] w_o_gpio_out;
wire  [p_num_gpios-1:0] w_i_gpio_in;
wire  [p_num_gpios-1:0] w_o_gpio_pullup;
wire  [p_num_gpios-1:0] w_o_gpio_pulldown;
wire  [p_num_gpios-1:0] w_o_gpio_out_en;


/******************
       Power
******************/

wire  vdd_io;
wire  vdd_co;
wire  vss;  

wire  netTie1;
wire  netTie0;

`KEEP_HIERARCHY
wrap_nettie nettie (
  .vdd_co             ( vdd_co               ),
  .vdd_io             ( vdd_io               ),
  .vss                ( vss                  ),
  .netTie0            ( netTie0              ),
  .netTie1            ( netTie1              )
);


/******************
     SoC main
******************/

`KEEP_HIERARCHY
// soc_full #(
soc_min #(
  .p_reset_vector     ( p_reset_vector       ),
  .p_imem_init        ( p_imem_init          ),
  .p_dmem_init        ( p_dmem_init          ),
  .p_num_gpios        ( p_num_gpios          ),
  .p_manufacturer_id  ( p_manufacturer_id    ),
  .p_product_id       ( p_product_id         ),
  .p_imem_depth_pw2   ( p_imem_depth_pw2     ),
  .p_dmem_depth_pw2   ( p_dmem_depth_pw2     ),
  .p_icache_en        ( p_icache_en          ),
  .p_icache_size_pw2  ( p_icache_size_pw2    ),
  .p_icache_line_pw2  ( p_icache_line_pw2    ),
  .p_icache_ways      ( p_icache_ways        ),
  .p_icache_repl      ( p_icache_repl        ),
  .p_dcache_en        ( p_dcache_en          ),
  .p_dcache_size_pw2  ( p_dcache_size_pw2    ),
  .p_dcache_line_pw2  ( p_dcache_line_pw2    ),
  .p_dcache_ways      ( p_dcache_ways        ),
  .p_dcache_repl      ( p_dcache_repl        ),
  .p_dcache_write_back  ( p_dcache_write_back  ),
  .p_dcache_write_alloc ( p_dcache_write_alloc ),
  .p_dcache_wbuf_depth  ( p_dcache_wbuf_depth  ),
  .p_imem_rd_latency    ( p_imem_rd_latency    ),
  .p_imem_burst_latency ( p_imem_burst_latency ),
  .p_dmem_rd_latency    ( p_dmem_rd_latency    ),
  .p_dmem_burst_latency ( p_dmem_burst_latency ),
  .p_dmem_wr_latency    ( p_dmem_wr_latency    ),
  .p_ext_rvc          ( p_ext_rvc            ),
  .p_ext_rve          ( p_ext_rve            ),
  .p_ext_rvm          ( p_ext_rvm            ),
  .p_ext_rvzicsr      ( p_ext_rvzicsr        ),
  .p_ext_custom       ( p_ext_custom         ),
  .p_counters         ( p_counters           ),
  .p_mul_fast         ( p_mul_fast           ),
  .p_mul_1_cycle      ( p_mul_1_cycle        ),
  .p_alu_share_adder  ( p_alu_share_adder    ),
  .p_alu_shift_bits   ( p_alu_shift_bits     ),
  .p_early_jal        ( p_early_jal          ),
  .p_redirect_buf     ( p_redirect_buf       ),
  .p_branch_stage     ( p_branch_stage       ),
  .p_fwd_ex           ( p_fwd_ex             ),
  .p_fwd_ma           ( p_fwd_ma             ),
  .p_fwd_wb           ( p_fwd_wb             ),
  .p_fwd_pw           ( p_fwd_pw             ),
  .p_pipeline         ( p_pipeline           ),
  .p_stage_IF         ( p_stage_IF           ),
  .p_stage_IC         ( p_stage_IC           ),
  .p_stage_ID         ( p_stage_ID           ),
  .p_stage_RF         ( p_stage_RF           ),
  .p_stage_EX         ( p_stage_EX           ),
  .p_stage_MA         ( p_stage_MA           ),
  .p_stage_WB         ( p_stage_WB           ),
  .p_branch_pred      ( p_branch_pred       ),
  .p_bp_index_bits    ( p_bp_index_bits     ),
  .p_bp_ctr_bits      ( p_bp_ctr_bits       ),
  .p_bp_ghr_bits      ( p_bp_ghr_bits       ),
  .p_fetch_buf        ( p_fetch_buf          ),
  .p_decode_buf       ( p_decode_buf         ),
  .p_rf_sp            ( p_rf_sp              ),
  .p_rf_read_buf      ( p_rf_read_buf        ),
  .p_branch_buf       ( p_branch_buf         ),
  .p_mem_buf          ( p_mem_buf            ),
  .p_wb_buf           ( p_wb_buf             ),
  .p_overlap           ( p_overlap             ),
  .p_wait_for_ack     ( p_wait_for_ack       )
) soc_top_level ( 
  .i_xclk             ( w_i_xclk             ),
  .i_pll_clk          ( w_i_pll_clk          ),
  .i_pll_locked       ( w_i_pll_locked       ),
  .o_pll_vco_en       ( w_o_pll_vco_en       ),
  .o_pll_cp_en        ( w_o_pll_cp_en        ),
  .o_pll_trim         ( w_o_pll_trim         ),
  .o_xtal_en          ( w_o_xtal_en          ),
  .o_clk              ( w_o_clk              ),
  .o_rst              ( w_o_rst              ),
  .o_regulator_en     ( w_o_regulator_en     ),
  .i_xrst             ( w_i_xrst             ),
  .i_por              ( w_i_por              ),

  .i_sck              ( w_i_sck              ),
  .i_sdi              ( w_i_sdi              ),
  .o_sdo              ( w_o_sdo              ),
  .o_sdo_en           ( w_o_sdo_en           ),
  .i_csb              ( w_i_csb              ),
  .o_flash_clk        ( w_o_flash_clk        ),
  .o_flash_clk_out_en ( w_o_flash_clk_out_en ),
  .o_flash_csb        ( w_o_flash_csb        ),
  .o_flash_csb_out_en ( w_o_flash_csb_out_en ),
  .i_flash_io0_din    ( w_i_flash_io0_din    ),
  .i_flash_io1_din    ( w_i_flash_io1_din    ),
  .i_flash_io2_din    ( w_i_flash_io2_din    ),
  .i_flash_io3_din    ( w_i_flash_io3_din    ),
  .o_flash_io0_dout   ( w_o_flash_io0_dout   ),
  .o_flash_io1_dout   ( w_o_flash_io1_dout   ),
  .o_flash_io2_dout   ( w_o_flash_io2_dout   ),
  .o_flash_io3_dout   ( w_o_flash_io3_dout   ),
  .o_flash_io0_out_en ( w_o_flash_io0_out_en ),
  .o_flash_io1_out_en ( w_o_flash_io1_out_en ),
  .o_flash_io2_out_en ( w_o_flash_io2_out_en ),
  .o_flash_io3_out_en ( w_o_flash_io3_out_en ),
  .o_gpio_out         ( w_o_gpio_out         ),
  .i_gpio_in          ( w_i_gpio_in          ),
  .o_gpio_pullup      ( w_o_gpio_pullup      ),
  .o_gpio_pulldown    ( w_o_gpio_pulldown    ),
  .o_gpio_out_en      ( w_o_gpio_out_en      )
);


/******************
    Pad settings
******************/

wire  pad_input;
wire  pad_output;
wire  pad_pullup_on;
wire  pad_pullup_off;
wire  pad_pulldown_on;
wire  pad_pulldown_off;

`KEEP_HIERARCHY
soc_pad_settings pad_settings (
  .netTie0         ( netTie0             ),
  .netTie1         ( netTie1             ),
  .pad_input       ( pad_input           ),
  .pad_output      ( pad_output          ),
  .pad_pullup_on   ( pad_pullup_on       ),
  .pad_pullup_off  ( pad_pullup_off      ),
  .pad_pulldown_on ( pad_pulldown_on     ),
  .pad_pulldown_off( pad_pulldown_off    )
);


/******************
       Clock
******************/

`KEEP_HIERARCHY
wrap_pll pll (
  .i_rst          ( w_i_por              ), //TODO: use global reset ?
  .i_xtal_p       ( w_i_xtal_p           ),
  .i_xtal_n       ( w_i_xtal_n           ),
  .o_clk          ( w_i_pll_clk          ),
  .o_locked       ( w_i_pll_locked       )
);

`KEEP_HIERARCHY
wrap_clock_pad P_i_xclk (
  .io_pad         ( i_xclk               ),
  .o_pad_in       ( w_i_xclk             ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);

`KEEP_HIERARCHY
wrap_input_pad P_i_xtal_p (
  .io_pad         ( i_xtal_p             ),
  .o_pad_in       ( w_i_xtal_p           ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);

`KEEP_HIERARCHY
wrap_input_pad P_i_xtal_n (
  .io_pad         ( i_xtal_n             ),
  .o_pad_in       ( w_i_xtal_n           ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);




/******************
        SPI
******************/

`KEEP_HIERARCHY
wrap_input_pad P_i_sck (
  .io_pad         ( i_sck                ),
  .o_pad_in       ( w_i_sck              ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);

`KEEP_HIERARCHY
wrap_input_pad P_i_sdi (
  .io_pad         ( i_sdi                ),
  .o_pad_in       ( w_i_sdi              ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);

`KEEP_HIERARCHY
wrap_output_pad P_o_sdo (
  .io_pad         ( o_sdo                ),
  .i_pad_out      ( w_o_sdo              ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);

`KEEP_HIERARCHY
wrap_input_pad P_i_csb (
  .io_pad         ( i_csb                ),
  .o_pad_in       ( w_i_csb              ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);


/******************
       FLASH
******************/

`KEEP_HIERARCHY
wrap_output_pad P_o_flash_csb (
  .io_pad         ( o_flash_csb          ),
  .i_pad_out      ( w_o_flash_csb        ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);

`KEEP_HIERARCHY
wrap_output_pad P_o_flash_clk (
  .io_pad         ( o_flash_clk          ),
  .i_pad_out      ( w_o_flash_clk        ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);

`KEEP_HIERARCHY
wrap_io_pad P_io_flash0(
  .io_pad         ( io_flash0            ),
  .o_pad_in       ( w_i_flash_io0_din    ),
  .i_pad_out      ( w_o_flash_io0_dout   ),
  .i_pad_out_en   ( w_o_flash_io0_out_en ),
  .i_pad_pullup   ( pad_pullup_off       ),
  .i_pad_pulldown ( pad_pulldown_off     ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);

`KEEP_HIERARCHY
wrap_io_pad P_io_flash1(
  .io_pad         ( io_flash1            ),
  .o_pad_in       ( w_i_flash_io1_din    ),
  .i_pad_out      ( w_o_flash_io1_dout   ),
  .i_pad_out_en   ( w_o_flash_io1_out_en ),
  .i_pad_pullup   ( pad_pullup_off       ),
  .i_pad_pulldown ( pad_pulldown_off     ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);

`KEEP_HIERARCHY
wrap_io_pad P_io_flash2(
  .io_pad         ( io_flash2            ),
  .o_pad_in       ( w_i_flash_io2_din    ),
  .i_pad_out      ( w_o_flash_io2_dout   ),
  .i_pad_out_en   ( w_o_flash_io2_out_en ),
  .i_pad_pullup   ( pad_pullup_off       ),
  .i_pad_pulldown ( pad_pulldown_off     ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);

`KEEP_HIERARCHY
wrap_io_pad P_io_flash3(
  .io_pad         ( io_flash3            ),
  .o_pad_in       ( w_i_flash_io3_din    ),
  .i_pad_out      ( w_o_flash_io3_dout   ),
  .i_pad_out_en   ( w_o_flash_io3_out_en ),
  .i_pad_pullup   ( pad_pullup_off       ),
  .i_pad_pulldown ( pad_pulldown_off     ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);


/******************
      Reset
******************/

`KEEP_HIERARCHY
wrap_input_pad P_i_xrst (
  .io_pad         ( i_xrst               ),
  .o_pad_in       ( w_i_xrst             ),
  .netTie0        ( netTie0              ),
  .netTie1        ( netTie1              ),
  .vdd_io         ( vdd_io               ),
  .vdd_co         ( vdd_co               ),
  .vss            ( vss                  )
);

`KEEP_HIERARCHY
wrap_por por(
 .i_clk           ( w_o_clk             ),
 .o_rst           ( w_i_por             )
);

/******************
       GPIOs
******************/

genvar i;
generate
  for (i = 0 ; i < p_num_gpios ; i = i+1) begin : P_io_GPIO
    `KEEP_HIERARCHY
    wrap_io_pad gen (
      .io_pad         ( io_gpio          [i] ),
      .o_pad_in       ( w_i_gpio_in      [i] ),
      .i_pad_out      ( w_o_gpio_out     [i] ),
      .i_pad_out_en   ( w_o_gpio_out_en  [i] ),
      .i_pad_pullup   ( w_o_gpio_pullup  [i] ),
      .i_pad_pulldown ( w_o_gpio_pulldown[i] ),
      .netTie0        ( netTie0              ),
      .netTie1        ( netTie1              ),
      .vdd_io         ( vdd_io               ),
      .vdd_co         ( vdd_co               ),
      .vss            ( vss                  )
    );
  end 
endgenerate

endmodule


`endif // __SOC_FULL__
