// PicoRV32 SoC top for Odatix synthesis.
// This top-level connects PicoRV32 to an internal RAM.
// External FPGA I/O is only clk, resetn, and trap.

module picorv32_soc_top #(	parameter [ 0:0] ENABLE_COUNTERS = 1,
	parameter [ 0:0] ENABLE_COUNTERS64 = 1,
	parameter [ 0:0] ENABLE_REGS_16_31 = 1,
	parameter [ 0:0] ENABLE_REGS_DUALPORT = 1,
	parameter [ 0:0] LATCHED_MEM_RDATA = 0,
	parameter [ 0:0] TWO_STAGE_SHIFT = 1,
	parameter [ 0:0] BARREL_SHIFTER = 0,
	parameter [ 0:0] TWO_CYCLE_COMPARE = 0,
	parameter [ 0:0] TWO_CYCLE_ALU = 0,
	parameter [ 0:0] COMPRESSED_ISA = 1,
	parameter [ 0:0] CATCH_MISALIGN = 1,
	parameter [ 0:0] CATCH_ILLINSN = 1,
	parameter [ 0:0] ENABLE_PCPI = 0,
	parameter [ 0:0] ENABLE_MUL = 0,
	parameter [ 0:0] ENABLE_FAST_MUL = 0,
	parameter [ 0:0] ENABLE_DIV = 0,
	parameter [ 0:0] ENABLE_IRQ = 0,
	parameter [ 0:0] ENABLE_IRQ_QREGS = 1,
	parameter [ 0:0] ENABLE_IRQ_TIMER = 1,
	parameter [ 0:0] ENABLE_TRACE = 0,
	parameter [ 0:0] REGS_INIT_ZERO = 0,
	parameter [31:0] MASKED_IRQ = 32'h 0000_0000,
	parameter [31:0] LATCHED_IRQ = 32'h ffff_ffff,
	parameter [31:0] PROGADDR_RESET = 32'h 0000_0000,
	parameter [31:0] PROGADDR_IRQ = 32'h 0000_0010,
	parameter [31:0] STACKADDR = 32'h ffff_ffff
) (
	input  wire clk,
	input  wire resetn,
	output wire trap
);

	wire        mem_valid;
	wire        mem_instr;
	wire        mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [ 3:0] mem_wstrb;
	wire [31:0] mem_rdata;

	wire        mem_la_read;
	wire        mem_la_write;
	wire [31:0] mem_la_addr;
	wire [31:0] mem_la_wdata;
	wire [ 3:0] mem_la_wstrb;

	wire        pcpi_valid;
	wire [31:0] pcpi_insn;
	wire [31:0] pcpi_rs1;
	wire [31:0] pcpi_rs2;

	wire [31:0] eoi;
	wire        trace_valid;
	wire [35:0] trace_data;

	picorv32 #(
		.ENABLE_COUNTERS     (ENABLE_COUNTERS),
		.ENABLE_COUNTERS64   (ENABLE_COUNTERS64),
		.ENABLE_REGS_16_31   (ENABLE_REGS_16_31),
		.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
		.LATCHED_MEM_RDATA   (LATCHED_MEM_RDATA),
		.TWO_STAGE_SHIFT     (TWO_STAGE_SHIFT),
		.BARREL_SHIFTER      (BARREL_SHIFTER),
		.TWO_CYCLE_COMPARE   (TWO_CYCLE_COMPARE),
		.TWO_CYCLE_ALU       (TWO_CYCLE_ALU),
		.COMPRESSED_ISA      (COMPRESSED_ISA),
		.CATCH_MISALIGN      (CATCH_MISALIGN),
		.CATCH_ILLINSN       (CATCH_ILLINSN),
		.ENABLE_PCPI         (ENABLE_PCPI),
		.ENABLE_MUL          (ENABLE_MUL),
		.ENABLE_FAST_MUL     (ENABLE_FAST_MUL),
		.ENABLE_DIV          (ENABLE_DIV),
		.ENABLE_IRQ          (ENABLE_IRQ),
		.ENABLE_IRQ_QREGS    (ENABLE_IRQ_QREGS),
		.ENABLE_IRQ_TIMER    (ENABLE_IRQ_TIMER),
		.ENABLE_TRACE        (ENABLE_TRACE),
		.REGS_INIT_ZERO      (REGS_INIT_ZERO),
		.MASKED_IRQ          (MASKED_IRQ),
		.LATCHED_IRQ         (LATCHED_IRQ),
		.PROGADDR_RESET      (PROGADDR_RESET),
		.PROGADDR_IRQ        (PROGADDR_IRQ),
		.STACKADDR           (STACKADDR)
	) cpu (
		.clk          (clk),
		.resetn       (resetn),
		.trap         (trap),

		.mem_valid    (mem_valid),
		.mem_instr    (mem_instr),
		.mem_ready    (mem_ready),
		.mem_addr     (mem_addr),
		.mem_wdata    (mem_wdata),
		.mem_wstrb    (mem_wstrb),
		.mem_rdata    (mem_rdata),

		.mem_la_read  (mem_la_read),
		.mem_la_write (mem_la_write),
		.mem_la_addr  (mem_la_addr),
		.mem_la_wdata (mem_la_wdata),
		.mem_la_wstrb (mem_la_wstrb),

		.pcpi_valid   (pcpi_valid),
		.pcpi_insn    (pcpi_insn),
		.pcpi_rs1     (pcpi_rs1),
		.pcpi_rs2     (pcpi_rs2),
		.pcpi_wr      (1'b0),
		.pcpi_rd      (32'h0000_0000),
		.pcpi_wait    (1'b0),
		.pcpi_ready   (1'b0),

		.irq          (32'h0000_0000),
		.eoi          (eoi),

		.trace_valid  (trace_valid),
		.trace_data   (trace_data)
	);

	picorv32_simple_ram #(
		.MEM_WORDS(1024)
	) ram (
		.clk       (clk),
		.mem_valid (mem_valid),
		.mem_ready (mem_ready),
		.mem_addr  (mem_addr),
		.mem_wdata (mem_wdata),
		.mem_wstrb (mem_wstrb),
		.mem_rdata (mem_rdata)
	);

endmodule
