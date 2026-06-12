// Date: 10.06.2026
// Description: Ariane SoC wrapper for CVA6 core with simple GPIO peripheral
// Top-level ports: clk_i, rst_ni, gpio_i, gpio_o

`include "rvfi_types.svh"
`include "cvxif_types.svh"

`define CVA6_KEEP(_field) _field: cva6_config_pkg::cva6_cfg._field

module cva6_soc_wrapper
  import ariane_pkg::*;
#(
  // ============================================================
  // Odatix-visible parameters
  // ============================================================

   
  parameter int unsigned GPIO_WIDTH_P = 32,
  //start
  parameter int unsigned DEBUG_EN_P = 1,

  parameter int unsigned PERF_COUNTER_EN_P = 1,

  parameter int unsigned MMU_PRESENT_P = 1,

  parameter int unsigned PMP_ENTRIES_P = 4,
  
  parameter int unsigned RVA_P = 1,
  
  parameter int unsigned RVC_P = 1,

  parameter int unsigned RVF_P = 0,

  parameter int unsigned RVD_P = 0,

  parameter int unsigned CVXIF_EN_P = 0,

  parameter int unsigned COPRO_TYPE_P = 0,

  parameter int unsigned ICACHE_BYTE_SIZE_P = 4096,

  parameter int unsigned DCACHE_BYTE_SIZE_P = 4096,

  parameter int unsigned D_CACHE_TYPE_P = 0,
  //end
  
  // ============================================================
  // CVA6 user configuration
  // Most fields are kept from the selected config package.
  // Only the fields above are controlled by Odatix.
  // ============================================================

  parameter config_pkg::cva6_user_cfg_t OdatixUserCfg = '{
    `CVA6_KEEP(XLEN),
    `CVA6_KEEP(VLEN),

    //`CVA6_KEEP(RVA), //decomment if you want to use a 64bit config
    RVA: RVA_P != 0, //comment if you want to use a 64bit config
    `CVA6_KEEP(RVB),
    `CVA6_KEEP(ZKN),
    `CVA6_KEEP(RVV),
    RVC: RVC_P != 0,
    `CVA6_KEEP(RVH),

    `CVA6_KEEP(RVZCB),
    `CVA6_KEEP(RVZCMP),
    `CVA6_KEEP(RVZCMT),
    `CVA6_KEEP(RVZiCond),
    `CVA6_KEEP(RVZiCbom),
    `CVA6_KEEP(RVZicntr),
    `CVA6_KEEP(RVZihpm),

    RVF: RVF_P != 0,
    RVD: RVD_P != 0,

    `CVA6_KEEP(XF16),
    `CVA6_KEEP(XF16ALT),
    `CVA6_KEEP(XF8),
    `CVA6_KEEP(XFVec),

    PerfCounterEn: PERF_COUNTER_EN_P != 0,
    MmuPresent:    MMU_PRESENT_P != 0,
    `CVA6_KEEP(RVS),
    `CVA6_KEEP(RVU),
    `CVA6_KEEP(SoftwareInterruptEn),
    DebugEn:       DEBUG_EN_P != 0,

    `CVA6_KEEP(DmBaseAddress),
    `CVA6_KEEP(HaltAddress),
    `CVA6_KEEP(ExceptionAddress),

    `CVA6_KEEP(SDTRIG),
    `CVA6_KEEP(Mcontrol6),
    `CVA6_KEEP(Icount),
    `CVA6_KEEP(Etrigger),
    `CVA6_KEEP(Itrigger),
    `CVA6_KEEP(TvalEn),
    `CVA6_KEEP(DirectVecOnly),

    NrPMPEntries: PMP_ENTRIES_P,
    `CVA6_KEEP(PMPCfgRstVal),
    `CVA6_KEEP(PMPAddrRstVal),
    `CVA6_KEEP(PMPEntryReadOnly),
    `CVA6_KEEP(PMPNapotEn),

    `CVA6_KEEP(NrNonIdempotentRules),
    `CVA6_KEEP(NonIdempotentAddrBase),
    `CVA6_KEEP(NonIdempotentLength),

    `CVA6_KEEP(NrExecuteRegionRules),
    `CVA6_KEEP(ExecuteRegionAddrBase),
    `CVA6_KEEP(ExecuteRegionLength),

    `CVA6_KEEP(NrCachedRegionRules),
    `CVA6_KEEP(CachedRegionAddrBase),
    `CVA6_KEEP(CachedRegionLength),

    CvxifEn:   CVXIF_EN_P != 0,
    CoproType: config_pkg::copro_type_t'(COPRO_TYPE_P),

    // This simple SoC wrapper assumes AXI-like NoC.
    NOCType: config_pkg::NOC_TYPE_AXI4_ATOP,

    `CVA6_KEEP(AxiAddrWidth),
    `CVA6_KEEP(AxiDataWidth),
    `CVA6_KEEP(AxiIdWidth),
    `CVA6_KEEP(AxiUserWidth),
    `CVA6_KEEP(AxiBurstWriteEn),
    `CVA6_KEEP(MemTidWidth),

    IcacheByteSize: ICACHE_BYTE_SIZE_P,
    `CVA6_KEEP(IcacheSetAssoc),
    `CVA6_KEEP(IcacheLineWidth),

    DCacheType:     config_pkg::cache_type_t'(D_CACHE_TYPE_P),
    `CVA6_KEEP(DcacheIdWidth),
    DcacheByteSize: DCACHE_BYTE_SIZE_P,
    `CVA6_KEEP(DcacheSetAssoc),
    `CVA6_KEEP(DcacheLineWidth),

    `CVA6_KEEP(DcacheFlushOnFence),
    `CVA6_KEEP(DcacheFlushOnFenceI),
    `CVA6_KEEP(DcacheInvalidateOnFlush),

    `CVA6_KEEP(DataUserEn),
    `CVA6_KEEP(WtDcacheWbufDepth),
    `CVA6_KEEP(FetchUserEn),
    `CVA6_KEEP(FetchUserWidth),

    `CVA6_KEEP(FpgaEn),
    `CVA6_KEEP(FpgaAlteraEn),
    `CVA6_KEEP(TechnoCut),

    `CVA6_KEEP(SuperscalarEn),
    `CVA6_KEEP(ALUBypass),
    `CVA6_KEEP(NrCommitPorts),
    `CVA6_KEEP(NrLoadPipeRegs),
    `CVA6_KEEP(NrStorePipeRegs),
    `CVA6_KEEP(NrScoreboardEntries),
    `CVA6_KEEP(NrLoadBufEntries),
    `CVA6_KEEP(MaxOutstandingStores),

    `CVA6_KEEP(RASDepth),
    `CVA6_KEEP(BTBEntries),
    `CVA6_KEEP(BPType),
    `CVA6_KEEP(BHTEntries),
    `CVA6_KEEP(BHTHist),

    `CVA6_KEEP(InstrTlbEntries),
    `CVA6_KEEP(DataTlbEntries),
    `CVA6_KEEP(UseSharedTlb),
    `CVA6_KEEP(SharedTlbDepth),
    `CVA6_KEEP(SvnapotEn)
  },

  parameter config_pkg::cva6_cfg_t CVA6Cfg =
    build_config_pkg::build_config(OdatixUserCfg),

  // ============================================================
  // RVFI types
  // ============================================================

  parameter type rvfi_probes_instr_t = `RVFI_PROBES_INSTR_T(CVA6Cfg),
  parameter type rvfi_probes_csr_t   = `RVFI_PROBES_CSR_T(CVA6Cfg),

  parameter type rvfi_probes_t = struct packed {
    rvfi_probes_csr_t   csr;
    rvfi_probes_instr_t instr;
  },

  // ============================================================
  // Accelerator dummy types
  // ============================================================

  parameter type accelerator_req_t  = logic,
  parameter type accelerator_resp_t = logic,

  parameter type acc_mmu_req_t  = logic,
  parameter type acc_mmu_resp_t = logic,

  parameter type acc_cfg_t = logic,
  parameter acc_cfg_t AccCfg = '0,

  // ============================================================
  // AXI / NoC types
  // ============================================================

  parameter type axi_ar_chan_t = struct packed {
    logic [CVA6Cfg.AxiIdWidth-1:0]   id;
    logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
    axi_pkg::len_t                   len;
    axi_pkg::size_t                  size;
    axi_pkg::burst_t                 burst;
    logic                            lock;
    axi_pkg::cache_t                 cache;
    axi_pkg::prot_t                  prot;
    axi_pkg::qos_t                   qos;
    axi_pkg::region_t                region;
    logic [CVA6Cfg.AxiUserWidth-1:0] user;
  },

  parameter type axi_aw_chan_t = struct packed {
    logic [CVA6Cfg.AxiIdWidth-1:0]   id;
    logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
    axi_pkg::len_t                   len;
    axi_pkg::size_t                  size;
    axi_pkg::burst_t                 burst;
    logic                            lock;
    axi_pkg::cache_t                 cache;
    axi_pkg::prot_t                  prot;
    axi_pkg::qos_t                   qos;
    axi_pkg::region_t                region;
    axi_pkg::atop_t                  atop;
    logic [CVA6Cfg.AxiUserWidth-1:0] user;
  },

  parameter type axi_w_chan_t = struct packed {
    logic [CVA6Cfg.AxiDataWidth-1:0]     data;
    logic [(CVA6Cfg.AxiDataWidth/8)-1:0] strb;
    logic                                last;
    logic [CVA6Cfg.AxiUserWidth-1:0]     user;
  },

  parameter type b_chan_t = struct packed {
    logic [CVA6Cfg.AxiIdWidth-1:0]   id;
    axi_pkg::resp_t                  resp;
    logic [CVA6Cfg.AxiUserWidth-1:0] user;
  },

  parameter type r_chan_t = struct packed {
    logic [CVA6Cfg.AxiIdWidth-1:0]   id;
    logic [CVA6Cfg.AxiDataWidth-1:0] data;
    axi_pkg::resp_t                  resp;
    logic                            last;
    logic [CVA6Cfg.AxiUserWidth-1:0] user;
  },

  parameter type noc_req_t = struct packed {
    axi_aw_chan_t aw;
    logic         aw_valid;
    axi_w_chan_t  w;
    logic         w_valid;
    logic         b_ready;
    axi_ar_chan_t ar;
    logic         ar_valid;
    logic         r_ready;
  },

  parameter type noc_resp_t = struct packed {
    logic    aw_ready;
    logic    ar_ready;
    logic    w_ready;
    logic    b_valid;
    b_chan_t b;
    logic    r_valid;
    r_chan_t r;
  },

  // ============================================================
  // CVXIF types
  // ============================================================

  localparam type readregflags_t =
    `READREGFLAGS_T(CVA6Cfg),

  localparam type writeregflags_t =
    `WRITEREGFLAGS_T(CVA6Cfg),

  localparam type id_t =
    `ID_T(CVA6Cfg),

  localparam type hartid_t =
    `HARTID_T(CVA6Cfg),

  localparam type x_compressed_req_t =
    `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t),

  localparam type x_compressed_resp_t =
    `X_COMPRESSED_RESP_T(CVA6Cfg),

  localparam type x_issue_req_t =
    `X_ISSUE_REQ_T(CVA6Cfg, hartid_t, id_t),

  localparam type x_issue_resp_t =
    `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t),

  localparam type x_register_t =
    `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t),

  localparam type x_commit_t =
    `X_COMMIT_T(CVA6Cfg, hartid_t, id_t),

  localparam type x_result_t =
    `X_RESULT_T(CVA6Cfg, hartid_t, id_t, writeregflags_t),

  localparam type cvxif_req_t =
    `CVXIF_REQ_T(
      CVA6Cfg,
      x_compressed_req_t,
      x_issue_req_t,
      x_register_t,
      x_commit_t
    ),

  localparam type cvxif_resp_t =
    `CVXIF_RESP_T(
      CVA6Cfg,
      x_compressed_resp_t,
      x_issue_resp_t,
      x_result_t
    )
) (
  input  logic                    clk_i,
  input  logic                    rstn_i,

  input  logic [GPIO_WIDTH_P-1:0] gpio_i,
  output logic [GPIO_WIDTH_P-1:0] gpio_o
);

  // ============================================================
  // Internal CVA6 signals
  // ============================================================

  logic [CVA6Cfg.VLEN-1:0] boot_addr_i;
  logic [CVA6Cfg.XLEN-1:0] hart_id_i;

  noc_req_t  noc_req;
  noc_resp_t noc_resp;

  cvxif_req_t  cvxif_req;
  cvxif_resp_t cvxif_resp;

  assign boot_addr_i = '0;
  assign hart_id_i   = '0;

  // pragma translate_off
  initial begin
    if (GPIO_WIDTH_P == 0) begin
      $fatal(1, "GPIO_WIDTH_P must be greater than 0.");
    end

    if (GPIO_WIDTH_P > CVA6Cfg.AxiDataWidth) begin
      $fatal(1, "GPIO_WIDTH_P must be <= CVA6Cfg.AxiDataWidth.");
    end

    if ((RVD_P != 0) && (RVF_P == 0)) begin
      $fatal(1, "RVD_P requires RVF_P.");
    end
  end
  // pragma translate_on

  // ============================================================
  // CVA6 core
  // ============================================================

    cva6 #(
    .CVA6Cfg              (CVA6Cfg),

    .rvfi_probes_instr_t  (rvfi_probes_instr_t),
    .rvfi_probes_csr_t    (rvfi_probes_csr_t),
    .rvfi_probes_t        (rvfi_probes_t),

    .accelerator_req_t    (accelerator_req_t),
    .accelerator_resp_t   (accelerator_resp_t),
    .acc_mmu_req_t        (acc_mmu_req_t),
    .acc_mmu_resp_t       (acc_mmu_resp_t),

    .axi_ar_chan_t        (axi_ar_chan_t),
    .axi_aw_chan_t        (axi_aw_chan_t),
    .axi_w_chan_t         (axi_w_chan_t),
    .b_chan_t             (b_chan_t),
    .r_chan_t             (r_chan_t),
    .noc_req_t            (noc_req_t),
    .noc_resp_t           (noc_resp_t),

    .acc_cfg_t            (acc_cfg_t),
    .AccCfg               (AccCfg),

    .readregflags_t       (readregflags_t),
    .writeregflags_t      (writeregflags_t),
    .id_t                 (id_t),
    .hartid_t             (hartid_t),
    .x_compressed_req_t   (x_compressed_req_t),
    .x_compressed_resp_t  (x_compressed_resp_t),
    .x_issue_req_t        (x_issue_req_t),
    .x_issue_resp_t       (x_issue_resp_t),
    .x_register_t         (x_register_t),
    .x_commit_t           (x_commit_t),
    .x_result_t           (x_result_t),
    .cvxif_req_t          (cvxif_req_t),
    .cvxif_resp_t         (cvxif_resp_t)
  ) i_cva6 (
    .clk_i                (clk_i),
    .rst_ni               (rstn_i),

    .boot_addr_i          (boot_addr_i),
    .hart_id_i            (hart_id_i),

    .irq_i                (2'b00),
    .ipi_i                (1'b0),
    .time_irq_i           (1'b0),
    .debug_req_i          (1'b0),

    .rvfi_probes_o        (),

    .cvxif_req_o          (cvxif_req),
    .cvxif_resp_i         (cvxif_resp),

    .noc_req_o            (noc_req),
    .noc_resp_i           (noc_resp)
  );

  // ============================================================
  // CVXIF coprocessor connection
  // ============================================================

  generate
    if (CVA6Cfg.CvxifEn) begin : gen_cvxif

      if (CVA6Cfg.CoproType == config_pkg::COPRO_EXAMPLE) begin : gen_copro_example

        cvxif_example_coprocessor #(
          .NrRgprPorts         (CVA6Cfg.NrRgprPorts),
          .XLEN                (CVA6Cfg.XLEN),

          .readregflags_t      (readregflags_t),
          .writeregflags_t     (writeregflags_t),
          .id_t                (id_t),
          .hartid_t            (hartid_t),

          .x_compressed_req_t  (x_compressed_req_t),
          .x_compressed_resp_t (x_compressed_resp_t),
          .x_issue_req_t       (x_issue_req_t),
          .x_issue_resp_t      (x_issue_resp_t),
          .x_register_t        (x_register_t),
          .x_commit_t          (x_commit_t),
          .x_result_t          (x_result_t),

          .cvxif_req_t         (cvxif_req_t),
          .cvxif_resp_t        (cvxif_resp_t)
        ) i_cvxif_coprocessor (
          .clk_i               (clk_i),
          .rst_ni              (rstn_i),

          .cvxif_req_i         (cvxif_req),
          .cvxif_resp_o        (cvxif_resp)
        );

      end else begin : gen_copro_none

        assign cvxif_resp = '{
          compressed_ready: 1'b1,
          issue_ready:      1'b1,
          register_ready:   1'b1,
          default:          '0
        };

      end

    end else begin : gen_no_cvxif

      assign cvxif_resp = '0;

    end
  endgenerate

  // ============================================================
  // Simple GPIO peripheral
  //
  // Address map:
  //   offset 0x00: gpio_o register, read/write
  //   offset 0x04: gpio_i register, read-only
  // ============================================================

    ariane_simple_axi_gpio #(
    .GPIO_WIDTH     (GPIO_WIDTH_P),
    .AXI_DATA_WIDTH (CVA6Cfg.AxiDataWidth),

    .axi_aw_chan_t  (axi_aw_chan_t),
    .axi_w_chan_t   (axi_w_chan_t),
    .axi_ar_chan_t  (axi_ar_chan_t),
    .b_chan_t       (b_chan_t),
    .r_chan_t       (r_chan_t),
    .noc_req_t      (noc_req_t),
    .noc_resp_t     (noc_resp_t)
  ) i_gpio (
    .clk_i          (clk_i),
    .rst_ni         (rstn_i),

    .axi_req_i      (noc_req),
    .axi_resp_o     (noc_resp),

    .gpio_i         (gpio_i),
    .gpio_o         (gpio_o)
  );

endmodule : cva6_soc_wrapper

`undef CVA6_KEEP


// ============================================================================
// Simple AXI-like GPIO slave
// ============================================================================

module ariane_simple_axi_gpio #(
  parameter int unsigned GPIO_WIDTH     = 32,
  parameter int unsigned AXI_DATA_WIDTH = 64,

  parameter type axi_aw_chan_t = logic,
  parameter type axi_w_chan_t  = logic,
  parameter type axi_ar_chan_t = logic,
  parameter type b_chan_t      = logic,
  parameter type r_chan_t      = logic,
  parameter type noc_req_t     = logic,
  parameter type noc_resp_t    = logic
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  noc_req_t              axi_req_i,
  output noc_resp_t             axi_resp_o,

  input  logic [GPIO_WIDTH-1:0] gpio_i,
  output logic [GPIO_WIDTH-1:0] gpio_o
);

  localparam int unsigned GPIO_EFF_WIDTH =
    (GPIO_WIDTH < AXI_DATA_WIDTH) ? GPIO_WIDTH : AXI_DATA_WIDTH;

  logic [GPIO_WIDTH-1:0] gpio_out_q;

  axi_aw_chan_t aw_q;
  axi_w_chan_t  w_q;

  logic aw_pending_q;
  logic w_pending_q;

  b_chan_t b_q;
  r_chan_t r_q;

  logic b_valid_q;
  logic r_valid_q;

  assign gpio_o = gpio_out_q;

  always_comb begin
    axi_resp_o = '0;

    axi_resp_o.aw_ready = !aw_pending_q && !b_valid_q;
    axi_resp_o.w_ready  = !w_pending_q  && !b_valid_q;
    axi_resp_o.ar_ready = !r_valid_q;

    axi_resp_o.b_valid = b_valid_q;
    axi_resp_o.b       = b_q;

    axi_resp_o.r_valid = r_valid_q;
    axi_resp_o.r       = r_q;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      gpio_out_q   <= '0;
      aw_q         <= '0;
      w_q          <= '0;
      aw_pending_q <= 1'b0;
      w_pending_q  <= 1'b0;
      b_q          <= '0;
      r_q          <= '0;
      b_valid_q    <= 1'b0;
      r_valid_q    <= 1'b0;
    end else begin

      if (axi_req_i.aw_valid && axi_resp_o.aw_ready) begin
        aw_q         <= axi_req_i.aw;
        aw_pending_q <= 1'b1;
      end

      if (axi_req_i.w_valid && axi_resp_o.w_ready) begin
        w_q         <= axi_req_i.w;
        w_pending_q <= 1'b1;
      end

      if (aw_pending_q && w_pending_q && !b_valid_q) begin
        b_valid_q    <= 1'b1;
        b_q          <= '0;
        b_q.id       <= aw_q.id;
        b_q.resp     <= '0;
        b_q.user     <= '0;
        aw_pending_q <= 1'b0;
        w_pending_q  <= 1'b0;

        unique case (aw_q.addr[5:2])
          4'h0: begin
            gpio_out_q[GPIO_EFF_WIDTH-1:0] <= w_q.data[GPIO_EFF_WIDTH-1:0];
          end

          default: begin
            gpio_out_q <= gpio_out_q;
          end
        endcase
      end

      if (b_valid_q && axi_req_i.b_ready) begin
        b_valid_q <= 1'b0;
      end

      if (axi_req_i.ar_valid && axi_resp_o.ar_ready) begin
        r_valid_q <= 1'b1;
        r_q       <= '0;
        r_q.id    <= axi_req_i.ar.id;
        r_q.resp  <= '0;
        r_q.last  <= 1'b1;
        r_q.user  <= '0;
        r_q.data  <= '0;

        unique case (axi_req_i.ar.addr[5:2])
          4'h0: begin
            r_q.data[GPIO_EFF_WIDTH-1:0] <= gpio_out_q[GPIO_EFF_WIDTH-1:0];
          end

          4'h1: begin
            r_q.data[GPIO_EFF_WIDTH-1:0] <= gpio_i[GPIO_EFF_WIDTH-1:0];
          end

          default: begin
            r_q.data <= '0;
          end
        endcase
      end

      if (r_valid_q && axi_req_i.r_ready) begin
        r_valid_q <= 1'b0;
      end

    end
  end

endmodule : ariane_simple_axi_gpio
