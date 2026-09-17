`default_nettype none

// Minimal wrapper for original PicoRV32 characterization with Odatix.

module picorv32_wrapper #(

  parameter ENABLE_COUNTERS = 1'b0,
  parameter ENABLE_COUNTERS64 = 1'b0,

  // <RegisterFile>
  parameter ENABLE_REGS_16_31 = 1'b1,
  parameter ENABLE_REGS_DUALPORT = 1'b0,
  // </RegisterFile>

  // <Shifter>
  parameter TWO_STAGE_SHIFT = 1'b0,
  parameter BARREL_SHIFTER = 1'b0,
  // </Shifter>

  // <Pipeline>
  parameter TWO_CYCLE_COMPARE = 1'b0,
  parameter TWO_CYCLE_ALU = 1'b0,
  // </Pipeline>

  // <ISA>
  parameter COMPRESSED_ISA = 1'b0,
  // </ISA>

  parameter CATCH_MISALIGN = 1'b1,
  parameter CATCH_ILLINSN = 1'b1,

  // <MulDiv>
  parameter ENABLE_MUL = 1'b0,
  parameter ENABLE_FAST_MUL = 1'b0,
  parameter ENABLE_DIV = 1'b0,
  // </MulDiv>

  parameter ENABLE_IRQ = 1'b0,
  parameter ENABLE_IRQ_QREGS = 1'b0,
  parameter ENABLE_IRQ_TIMER = 1'b0,

  parameter ENABLE_TRACE = 1'b0,
  parameter REGS_INIT_ZERO = 1'b0,

  parameter MASKED_IRQ = 32'h00000000,
  parameter LATCHED_IRQ = 32'hffffffff,

  parameter PROGADDR_RESET = 32'h00000000,
  parameter PROGADDR_IRQ = 32'h00000010,

  parameter STACKADDR = 32'hffffffff

) (

  // Clock / reset
  input wire clk,
  input wire resetn,


  // ----------------------------------------------------------
  // Native PicoRV32 memory interface
  // ----------------------------------------------------------

  output wire        mem_valid,
  output wire        mem_instr,

  input  wire        mem_ready,

  output wire [31:0] mem_addr,
  output wire [31:0] mem_wdata,
  output wire [3:0]  mem_wstrb,

  input  wire [31:0] mem_rdata
);


  // ----------------------------------------------------------
  // Unused PicoRV32 interfaces
  // ----------------------------------------------------------

  wire trap_unused;

  // Look-ahead memory interface
  wire        mem_la_read_unused;
  wire        mem_la_write_unused;
  wire [31:0] mem_la_addr_unused;
  wire [31:0] mem_la_wdata_unused;
  wire [3:0]  mem_la_wstrb_unused;

  // PCPI outputs
  wire        pcpi_valid_unused;
  wire [31:0] pcpi_insn_unused;
  wire [31:0] pcpi_rs1_unused;
  wire [31:0] pcpi_rs2_unused;

  // IRQ response
  wire [31:0] eoi_unused;

  // Trace
  wire        trace_valid_unused;
  wire [35:0] trace_data_unused;

  // ----------------------------------------------------------
  // Original PicoRV32 core
  // ----------------------------------------------------------
  `KEEP_HIERARCHY
  picorv32 #(

    .ENABLE_COUNTERS      (ENABLE_COUNTERS),
    .ENABLE_COUNTERS64    (ENABLE_COUNTERS64),

    .ENABLE_REGS_16_31    (ENABLE_REGS_16_31),
    .ENABLE_REGS_DUALPORT (ENABLE_REGS_DUALPORT),

    // These two PicoRV32 parameters are not part of your
    // platform configuration, so keep their original/default
    // behavior fixed.
    .LATCHED_MEM_RDATA    (1'b0),
    .ENABLE_PCPI          (1'b0),

    .TWO_STAGE_SHIFT      (TWO_STAGE_SHIFT),
    .BARREL_SHIFTER       (BARREL_SHIFTER),

    .TWO_CYCLE_COMPARE    (TWO_CYCLE_COMPARE),
    .TWO_CYCLE_ALU        (TWO_CYCLE_ALU),

    .COMPRESSED_ISA       (COMPRESSED_ISA),

    .CATCH_MISALIGN       (CATCH_MISALIGN),
    .CATCH_ILLINSN        (CATCH_ILLINSN),

    .ENABLE_MUL           (ENABLE_MUL),
    .ENABLE_FAST_MUL      (ENABLE_FAST_MUL),
    .ENABLE_DIV           (ENABLE_DIV),

    .ENABLE_IRQ           (ENABLE_IRQ),
    .ENABLE_IRQ_QREGS     (ENABLE_IRQ_QREGS),
    .ENABLE_IRQ_TIMER     (ENABLE_IRQ_TIMER),

    .ENABLE_TRACE         (ENABLE_TRACE),
    .REGS_INIT_ZERO       (REGS_INIT_ZERO),

    .MASKED_IRQ           (MASKED_IRQ),
    .LATCHED_IRQ          (LATCHED_IRQ),

    .PROGADDR_RESET       (PROGADDR_RESET),
    .PROGADDR_IRQ         (PROGADDR_IRQ),

    .STACKADDR            (STACKADDR)

  ) u_picorv32 (

    // Clock / reset
    .clk          (clk),
    .resetn       (resetn),

    // Trap
    .trap         (trap_unused),

    // --------------------------------------------------------
    // Native memory interface
    // --------------------------------------------------------

    .mem_valid    (mem_valid),
    .mem_instr    (mem_instr),
    .mem_ready    (mem_ready),

    .mem_addr     (mem_addr),
    .mem_wdata    (mem_wdata),
    .mem_wstrb    (mem_wstrb),
    .mem_rdata    (mem_rdata),

    // --------------------------------------------------------
    // Look-ahead interface unused
    // --------------------------------------------------------

    .mem_la_read  (mem_la_read_unused),
    .mem_la_write (mem_la_write_unused),
    .mem_la_addr  (mem_la_addr_unused),
    .mem_la_wdata (mem_la_wdata_unused),
    .mem_la_wstrb (mem_la_wstrb_unused),

    // --------------------------------------------------------
    // External PCPI disabled
    // --------------------------------------------------------

    .pcpi_valid   (pcpi_valid_unused),
    .pcpi_insn    (pcpi_insn_unused),
    .pcpi_rs1     (pcpi_rs1_unused),
    .pcpi_rs2     (pcpi_rs2_unused),

    .pcpi_wr      (1'b0),
    .pcpi_rd      (32'b0),
    .pcpi_wait    (1'b0),
    .pcpi_ready   (1'b0),

    // --------------------------------------------------------
    // Interrupts disabled externally
    //
    // ENABLE_IRQ remains configurable because it is one of
    // your existing Odatix parameters, but no IRQ source is
    // connected in this core-only environment.
    // --------------------------------------------------------

    .irq          (32'b0),
    .eoi          (eoi_unused),

    // --------------------------------------------------------
    // Trace
    // --------------------------------------------------------

    .trace_valid  (trace_valid_unused),
    .trace_data   (trace_data_unused)

  );

endmodule

`default_nettype wire
