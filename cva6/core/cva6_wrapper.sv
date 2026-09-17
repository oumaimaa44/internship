// CVA6 synthesis wrapper for Odatix Fmax exploration.
//
// External interface:
//   - clk_i
//   - rst_ni (active low)
//   - gpio_o (memory-mapped observable output)
//
// The wrapper keeps the CVA6 target configuration selected by the normal
// CVA6 build flow (cva6_config_pkg::cva6_cfg) and overrides only the Odatix
// parameters exposed below.  The final CVA6Cfg is rebuilt with the official
// build_config_pkg::build_config() function.
//
// Memory path:
//   ariane -> axi_atop_filter -> axi_to_mem -> internal synchronous RAM/MMIO
//
// Required CVA6/vendor sources include the normal CVA6 RTL plus the PULP AXI
// modules axi_atop_filter and axi_to_mem (normally available in the CVA6 repo's
// vendor dependencies).
`include "soc_config.sv"
`include "axi/assign.svh"
module cva6_wrapper #(
    parameter BOOT_ADDR = 32'h0000_0000,
    // <ISA>
    parameter CVA6ConfigCExtEn = 0,
    // </ISA>
    // <Cache>
    parameter CVA6ConfigIcacheByteSize  = 256,
    parameter CVA6ConfigIcacheSetAssoc  = 1,
    parameter CVA6ConfigIcacheLineWidth = 128,
    parameter CVA6ConfigDcacheByteSize  = 512,
    parameter CVA6ConfigDcacheSetAssoc  = 1,
    parameter CVA6ConfigDcacheLineWidth = 128,
    // </Cache>
    // <Scoreboard>
    parameter CVA6ConfigNrScoreboardEntries = 4,
    // </Scoreboard>
    // <Pipeline>
    parameter CVA6ConfigNrLoadPipeRegs  = 0,
    parameter CVA6ConfigNrStorePipeRegs = 0,
    // </Pipeline>
    // <LoadBuff>
    parameter CVA6ConfigNrLoadBufEntries = 2,
    // </LoadBuff>
    // <BranchPred>
    parameter CVA6ConfigRASDepth   = 2,
    parameter CVA6ConfigBTBEntries = 0,
    parameter CVA6ConfigBHTEntries = 0,
    // </BranchPred>
    // <PMP>
    parameter CVA6ConfigNrPMPEntries = 0,
    // </PMP>
    // <PerfCounter>
    parameter CVA6ConfigPerfCounterEn = 0
    // </PerfCounter>
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    output logic [31:0] gpio_o
);

  // --------------------------------------------------------------------------
  // Fixed wrapper configuration (not part of the Odatix exploration space)
  // --------------------------------------------------------------------------
  localparam integer      RAM_BYTE_ADDR_WIDTH = 14;  // 16 KiB internal RAM
  localparam logic [63:0] GPIO_ADDR           = 64'h0000_0000_1000_0000;
  localparam integer      AXI_MAX_WRITE_TXNS  = 4;

  // --------------------------------------------------------------------------
  // Build the CVA6 configuration.
  // Start from the target selected by the CVA6 build flow and override only
  // the parameters intentionally exposed by this wrapper.
  // --------------------------------------------------------------------------
  function automatic config_pkg::cva6_user_cfg_t make_cva6_user_cfg(
      input config_pkg::cva6_user_cfg_t base_cfg
  );
    config_pkg::cva6_user_cfg_t cfg;
    begin
      cfg = base_cfg;

      // ISA
      cfg.RVC = bit'(CVA6ConfigCExtEn);

      // Caches
      cfg.IcacheByteSize  = unsigned'(CVA6ConfigIcacheByteSize);
      cfg.IcacheSetAssoc  = unsigned'(CVA6ConfigIcacheSetAssoc);
      cfg.IcacheLineWidth = unsigned'(CVA6ConfigIcacheLineWidth);
      cfg.DcacheByteSize  = unsigned'(CVA6ConfigDcacheByteSize);
      cfg.DcacheSetAssoc  = unsigned'(CVA6ConfigDcacheSetAssoc);
      cfg.DcacheLineWidth = unsigned'(CVA6ConfigDcacheLineWidth);

      // Scoreboard
      cfg.NrScoreboardEntries = unsigned'(CVA6ConfigNrScoreboardEntries);

      // Pipeline
      cfg.NrLoadPipeRegs  = unsigned'(CVA6ConfigNrLoadPipeRegs);
      cfg.NrStorePipeRegs = unsigned'(CVA6ConfigNrStorePipeRegs);

      // Load buffer
      cfg.NrLoadBufEntries = unsigned'(CVA6ConfigNrLoadBufEntries);

      // Branch prediction
      cfg.RASDepth   = unsigned'(CVA6ConfigRASDepth);
      cfg.BTBEntries = unsigned'(CVA6ConfigBTBEntries);
      cfg.BHTEntries = unsigned'(CVA6ConfigBHTEntries);

      // PMP
      cfg.NrPMPEntries = unsigned'(CVA6ConfigNrPMPEntries);

      // Performance counters
      cfg.PerfCounterEn = bit'(CVA6ConfigPerfCounterEn);

      make_cva6_user_cfg = cfg;
    end
  endfunction

  localparam config_pkg::cva6_user_cfg_t CVA6UserCfg =
      make_cva6_user_cfg(cva6_config_pkg::cva6_cfg);

  localparam config_pkg::cva6_cfg_t CVA6Cfg =
      build_config_pkg::build_config(CVA6UserCfg);

  localparam logic [CVA6Cfg.VLEN-1:0] BOOT_ADDR_INT = BOOT_ADDR;

  // --------------------------------------------------------------------------
  // CVA6 AXI NoC signals
  // --------------------------------------------------------------------------
  ariane_axi::req_t  core_axi_req;
  ariane_axi::resp_t core_axi_resp;

  ariane_axi::req_t  mem_axi_req;
  ariane_axi::resp_t mem_axi_resp;

  // --------------------------------------------------------------------------
  // CVA6 core wrapper (ariane)
  // --------------------------------------------------------------------------
  `KEEP_HIERARCHY
  ariane #(
      .CVA6Cfg   (CVA6Cfg),
      .noc_req_t (ariane_axi::req_t),
      .noc_resp_t(ariane_axi::resp_t)
  ) i_ariane (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .boot_addr_i   (BOOT_ADDR_INT),
      .hart_id_i     ('0),

      // No external interrupts in the Fmax wrapper.
      .irq_i         ('0),
      .ipi_i         (1'b0),
      .time_irq_i    (1'b0),
      .debug_req_i   (1'b0),

      // Formal tracing is not needed for synthesis/Fmax exploration.
      .rvfi_probes_o (),

      .noc_req_o     (core_axi_req),
      .noc_resp_i    (core_axi_resp)
  );

  // --------------------------------------------------------------------------
  // Protocol-safe ATOP filter.
  // Our small internal RAM does not implement atomic memory operations.  The
  // official PULP AXI filter absorbs ATOP transactions and returns SLVERR while
  // passing ordinary AXI transactions unchanged.
  // --------------------------------------------------------------------------
  `KEEP_HIERARCHY
  axi_atop_filter #(
      .AxiIdWidth      (CVA6Cfg.AxiIdWidth),
      .AxiMaxWriteTxns (AXI_MAX_WRITE_TXNS),
      .req_t           (ariane_axi::req_t),
      .resp_t          (ariane_axi::resp_t)
  ) i_axi_atop_filter (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .slv_req_i  (core_axi_req),
      .slv_resp_o (core_axi_resp),
      .mst_req_o  (mem_axi_req),
      .mst_resp_i (mem_axi_resp)
  );

  // --------------------------------------------------------------------------
  // Legacy AXI_BUS -> simple memory stream.
  //
  // This CVA6 tree uses the legacy axi2mem adapter.  The core/ATOP filter use
  // packed ariane_axi request/response structs, while axi2mem expects an
  // AXI_BUS.Slave interface.  The standard AXI assignment macros bridge the
  // two representations without changing the protocol.
  // --------------------------------------------------------------------------
  AXI_BUS #(
      .AXI_ADDR_WIDTH (CVA6Cfg.AxiAddrWidth),
      .AXI_DATA_WIDTH (CVA6Cfg.AxiDataWidth),
      .AXI_ID_WIDTH   (CVA6Cfg.AxiIdWidth),
      .AXI_USER_WIDTH (ariane_axi::UserWidth)
  ) mem_axi_bus();

  `AXI_ASSIGN_FROM_REQ(mem_axi_bus, mem_axi_req)
  `AXI_ASSIGN_TO_RESP(mem_axi_resp, mem_axi_bus)

  logic                              mem_req;
  logic                              mem_we;
  logic [CVA6Cfg.AxiAddrWidth-1:0]   mem_addr;
  logic [CVA6Cfg.AxiDataWidth-1:0]   mem_wdata;
  logic [CVA6Cfg.AxiDataWidth-1:0]   mem_rdata;
  logic [CVA6Cfg.AxiDataWidth/8-1:0] mem_strb;

  `KEEP_HIERARCHY
  axi2mem #(
      .AXI_ID_WIDTH   (CVA6Cfg.AxiIdWidth),
      .AXI_ADDR_WIDTH (CVA6Cfg.AxiAddrWidth),
      .AXI_DATA_WIDTH (CVA6Cfg.AxiDataWidth),
      .AXI_USER_WIDTH (ariane_axi::UserWidth)
  ) i_axi2mem (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      .slave  (mem_axi_bus),

      .req_o  (mem_req),
      .we_o   (mem_we),
      .addr_o (mem_addr),
      .be_o   (mem_strb),
      .user_o (),
      .data_o (mem_wdata),

      // The local RAM does not attach AXI user metadata to read responses.
      .user_i ('0),
      .data_i (mem_rdata)
  );

  // --------------------------------------------------------------------------
  // Internal one-cycle memory + observable MMIO GPIO register.
  // The RAM aliases over the address space using its low address bits. This is
  // intentional for a compact synthesis/Fmax harness; GPIO_ADDR is decoded
  // explicitly before RAM access.
  // --------------------------------------------------------------------------
  `KEEP_HIERARCHY
  cva6_mem #(
      .ADDR_WIDTH          (CVA6Cfg.AxiAddrWidth),
      .DATA_WIDTH          (CVA6Cfg.AxiDataWidth),
      .RAM_BYTE_ADDR_WIDTH (RAM_BYTE_ADDR_WIDTH),
      .GPIO_ADDR           (GPIO_ADDR)
  ) i_mem (
      .clk_i    (clk_i),
      .rst_ni   (rst_ni),
      .req_i    (mem_req),
      .we_i     (mem_we),
      .addr_i   (mem_addr),
      .strb_i   (mem_strb),
      .wdata_i  (mem_wdata),
      .rvalid_o (),
      .rdata_o  (mem_rdata),
      .gpio_o   (gpio_o)
  );

endmodule


// ============================================================================
// Simple synthesis-clean memory for the CVA6 Odatix wrapper.
//
// - One request accepted every cycle.
// - One-cycle response latency.
// - Read data is registered with one-cycle latency for legacy axi2mem.
// - Byte write strobes are honored.
// - No DPI, no plusargs, no $display, no testbench-only constructs.
// ============================================================================
module cva6_mem #(
    parameter integer ADDR_WIDTH          = 64,
    parameter integer DATA_WIDTH          = 64,
    parameter integer RAM_BYTE_ADDR_WIDTH = 14,
    parameter logic [63:0] GPIO_ADDR      = 64'h0000_0000_1000_0000
) (
    input  logic                       clk_i,
    input  logic                       rst_ni,

    input  logic                       req_i,
    input  logic                       we_i,
    input  logic [ADDR_WIDTH-1:0]      addr_i,
    input  logic [DATA_WIDTH/8-1:0]    strb_i,
    input  logic [DATA_WIDTH-1:0]      wdata_i,

    output logic                       rvalid_o,
    output logic [DATA_WIDTH-1:0]      rdata_o,
    output logic [31:0]                gpio_o
);

  localparam integer BYTE_SHIFT      = $clog2(DATA_WIDTH / 8);
  localparam integer WORD_ADDR_WIDTH = RAM_BYTE_ADDR_WIDTH - BYTE_SHIFT;
  localparam integer WORDS           = (1 << WORD_ADDR_WIDTH);
  localparam integer GPIO_BYTES      = ((DATA_WIDTH / 8) < 4) ? (DATA_WIDTH / 8) : 4;
  localparam integer GPIO_DATA_BITS  = (DATA_WIDTH < 32) ? DATA_WIDTH : 32;

  // Keep the memory itself in a clock-only process.  In particular, do not put
  // it in a process with an asynchronous reset: Vivado cannot infer BRAM from
  // that coding style.
  (* ram_style = "block" *)
  logic [DATA_WIDTH-1:0] mem [0:WORDS-1];

  logic [WORD_ADDR_WIDTH-1:0] word_addr;
  logic                       gpio_sel;
  logic [DATA_WIDTH-1:0]      gpio_read_data;
  logic [ADDR_WIDTH-1:0]      gpio_addr_int;

  assign word_addr     = addr_i[RAM_BYTE_ADDR_WIDTH-1:BYTE_SHIFT];
  assign gpio_addr_int = GPIO_ADDR[ADDR_WIDTH-1:0];
  assign gpio_sel      = (addr_i == gpio_addr_int);

  always_comb begin
    gpio_read_data = '0;
    gpio_read_data[GPIO_DATA_BITS-1:0] = gpio_o[GPIO_DATA_BITS-1:0];
  end

  // Response-valid state may use the asynchronous reset; it is not part of the
  // RAM inference process.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
      rvalid_o <= 1'b0;
    else
      rvalid_o <= req_i;
  end

  // MMIO GPIO register is also kept separate from the inferred RAM.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      gpio_o <= 32'h0000_0000;
    end else if (req_i && we_i && gpio_sel) begin
      for (int i = 0; i < GPIO_BYTES; i++) begin
        if (strb_i[i])
          gpio_o[i*8 +: 8] <= wdata_i[i*8 +: 8];
      end
    end
  end

  // BRAM-compatible synchronous memory process: no asynchronous reset.
  // Reads have one-cycle latency, matching the legacy axi2mem adapter.
  always_ff @(posedge clk_i) begin
    if (req_i) begin
      if (we_i) begin
        if (!gpio_sel) begin
          for (int i = 0; i < DATA_WIDTH/8; i++) begin
            if (strb_i[i])
              mem[word_addr][i*8 +: 8] <= wdata_i[i*8 +: 8];
          end
        end
        rdata_o <= '0;
      end else begin
        if (gpio_sel)
          rdata_o <= gpio_read_data;
        else
          rdata_o <= mem[word_addr];
      end
    end
  end

endmodule