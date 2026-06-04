// Simple internal RAM for PicoRV32 native memory interface.
// This RAM is not exposed as FPGA I/O.
// It is connected internally to the PicoRV32 mem_* bus.

module picorv32_simple_ram #(
	parameter integer MEM_WORDS = 1024
) (
	input  wire        clk,

	input  wire        mem_valid,
	output reg         mem_ready,

	input  wire [31:0] mem_addr,
	input  wire [31:0] mem_wdata,
	input  wire [ 3:0] mem_wstrb,
	output reg  [31:0] mem_rdata
);

	localparam integer MEM_ADDR_WIDTH = 10; // log2(1024), for MEM_WORDS = 1024

	wire [MEM_ADDR_WIDTH-1:0] mem_word_addr;
	assign mem_word_addr = mem_addr[MEM_ADDR_WIDTH+1:2];

	reg [31:0] memory [0:MEM_WORDS-1];

	integer i;
	initial begin
		// Fill memory with RISC-V NOP instructions.
		// NOP = ADDI x0, x0, 0 = 32'h00000013
		for (i = 0; i < MEM_WORDS; i = i + 1)
			memory[i] = 32'h0000_0013;
	end

	always @(posedge clk) begin
		mem_ready <= 1'b0;

		if (mem_valid && !mem_ready) begin
			mem_ready <= 1'b1;

			if (mem_addr < 4*MEM_WORDS) begin
				mem_rdata <= memory[mem_word_addr];

				if (mem_wstrb[0]) memory[mem_word_addr][ 7: 0] <= mem_wdata[ 7: 0];
				if (mem_wstrb[1]) memory[mem_word_addr][15: 8] <= mem_wdata[15: 8];
				if (mem_wstrb[2]) memory[mem_word_addr][23:16] <= mem_wdata[23:16];
				if (mem_wstrb[3]) memory[mem_word_addr][31:24] <= mem_wdata[31:24];
			end else begin
				// Out-of-range reads return NOP.
				mem_rdata <= 32'h0000_0013;
			end
		end
	end

endmodule
