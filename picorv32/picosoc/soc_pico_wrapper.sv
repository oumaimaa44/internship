// Odatix synthesis wrapper around the official PicoSoC.
// Only the PicoRV32 parameters used in the exploration are exposed here.

`include "soc_config.sv"

module soc_pico_wrapper #(
    // <RegisterFile>
    parameter ENABLE_REGS_16_31     = 1'b1,
    parameter ENABLE_REGS_DUALPORT  = 1'b0,
    // </RegisterFile>

    // <Shifter>
    parameter TWO_STAGE_SHIFT       = 1'b0,
    parameter BARREL_SHIFTER        = 1'b0,
    // </Shifter>

    // <Pipeline>
    parameter TWO_CYCLE_COMPARE     = 1'b0,
    parameter TWO_CYCLE_ALU         = 1'b0,
    // </Pipeline>

    // <ISA>
    parameter COMPRESSED_ISA        = 1'b0,
    // </ISA>

    parameter CATCH_MISALIGN        = 1'b1,
    parameter CATCH_ILLINSN         = 1'b1,

    // <MulDiv>
    parameter ENABLE_MUL            = 1'b0,
    parameter ENABLE_FAST_MUL       = 1'b0,
    parameter ENABLE_DIV            = 1'b0
    // </MulDiv>
) (
    input  wire        clk_i,
    input  wire        rst_ni,
    output wire [31:0] gpio_o
);

    wire        iomem_valid;
    wire [3:0]  iomem_wstrb;
    wire [31:0] iomem_addr;
    wire [31:0] iomem_wdata;

    wire ser_tx;
    wire flash_csb;
    wire flash_clk;

    wire flash_io0_oe;
    wire flash_io1_oe;
    wire flash_io2_oe;
    wire flash_io3_oe;

    wire flash_io0_do;
    wire flash_io1_do;
    wire flash_io2_do;
    wire flash_io3_do;

    `KEEP_HIERARCHY
    picosoc #(
        .ENABLE_REGS_16_31     (ENABLE_REGS_16_31),
        .ENABLE_REGS_DUALPORT  (ENABLE_REGS_DUALPORT),

        .TWO_STAGE_SHIFT       (TWO_STAGE_SHIFT),
        .BARREL_SHIFTER        (BARREL_SHIFTER),

        .TWO_CYCLE_COMPARE     (TWO_CYCLE_COMPARE),
        .TWO_CYCLE_ALU         (TWO_CYCLE_ALU),

        .ENABLE_COMPRESSED     (COMPRESSED_ISA),
        .CATCH_MISALIGN        (CATCH_MISALIGN),
        .CATCH_ILLINSN         (CATCH_ILLINSN),

        .ENABLE_MUL            (ENABLE_MUL),
        .ENABLE_FAST_MUL       (ENABLE_FAST_MUL),
        .ENABLE_DIV            (ENABLE_DIV)
    ) soc_i (
        .clk          (clk_i),
        .resetn       (rst_ni),

        .iomem_valid  (iomem_valid),
        .iomem_ready  (1'b1),
        .iomem_wstrb  (iomem_wstrb),
        .iomem_addr   (iomem_addr),
        .iomem_wdata  (iomem_wdata),
        .iomem_rdata  (32'b0),

        .irq_5        (1'b0),
        .irq_6        (1'b0),
        .irq_7        (1'b0),

        .ser_tx       (ser_tx),
        .ser_rx       (1'b1),

        .flash_csb    (flash_csb),
        .flash_clk    (flash_clk),

        .flash_io0_oe (flash_io0_oe),
        .flash_io1_oe (flash_io1_oe),
        .flash_io2_oe (flash_io2_oe),
        .flash_io3_oe (flash_io3_oe),

        .flash_io0_do (flash_io0_do),
        .flash_io1_do (flash_io1_do),
        .flash_io2_do (flash_io2_do),
        .flash_io3_do (flash_io3_do),

        .flash_io0_di (1'b0),
        .flash_io1_di (1'b0),
        .flash_io2_di (1'b0),
        .flash_io3_di (1'b0)
    );

    assign gpio_o = {
        iomem_addr[15:0],
        iomem_wstrb,
        iomem_valid,
        ser_tx,
        flash_csb,
        flash_clk,
        flash_io3_oe,
        flash_io2_oe,
        flash_io1_oe,
        flash_io0_oe,
        flash_io3_do,
        flash_io2_do,
        flash_io1_do,
        flash_io0_do
    };

endmodule