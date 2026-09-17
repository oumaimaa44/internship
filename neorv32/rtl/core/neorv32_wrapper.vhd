-- =============================================================================
-- NEORV32 Odatix synthesis wrapper
--
-- Purpose:
--   * Keep the official neorv32_top unchanged.
--   * Expose only the requested architectural parameters.
--   * Use the official internal IMEM/DMEM of NEORV32.
--   * Keep external top-level interface minimal: clock, reset, observable GPIO.
--
-- Notes:
--   * rstn_i is active-low, matching neorv32_top.
--   * BOOT_MODE_SELECT = 1 makes BOOT_ADDR drive the CPU custom boot address.
--   * IMEM: 16 KiB at 0x00000000
--   * DMEM:  8 KiB at 0x80000000
--   * One GPIO bit is implemented to provide an observable CPU-to-output path.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.neorv32_package.all;


entity neorv32_wrapper is
  generic (
    -- <main>
    BOOT_ADDR : std_ulogic_vector(31 downto 0) := x"00000000";

    -- <ISA>
    RISCV_ISA_C         : boolean := false;
    RISCV_ISA_E         : boolean := false;
    RISCV_ISA_M         : boolean := false;
    RISCV_ISA_U         : boolean := false;
    RISCV_ISA_Zmmul     : boolean := false;
    -- </ISA>
    RISCV_ISA_Zaamo     : boolean := false;
    RISCV_ISA_Zalrsc    : boolean := false;

    -- <BitManip>
    RISCV_ISA_Zba       : boolean := false;
    RISCV_ISA_Zbb       : boolean := false;
    RISCV_ISA_Zbc       : boolean := false;
    RISCV_ISA_Zbs       : boolean := false;
    RISCV_ISA_Zcb       : boolean := false;
    -- </BitManip>
    RISCV_ISA_Zbkb      : boolean := false;
    RISCV_ISA_Zbkc      : boolean := false;
    RISCV_ISA_Zbkx      : boolean := false;
    RISCV_ISA_Zfinx     : boolean := false;
    RISCV_ISA_Zibi      : boolean := false;
    RISCV_ISA_Zicntr    : boolean := false;
    RISCV_ISA_Zicond    : boolean := false;
    RISCV_ISA_Zihpm     : boolean := false;
    RISCV_ISA_Zimop     : boolean := false;
    RISCV_ISA_Zknd      : boolean := false;
    RISCV_ISA_Zkne      : boolean := false;
    RISCV_ISA_Zknh      : boolean := false;
    RISCV_ISA_Zksed     : boolean := false;
    RISCV_ISA_Zksh      : boolean := false;
    RISCV_ISA_Smcntrpmf : boolean := false;
    RISCV_ISA_Xcfu      : boolean := false;

    -- <MicroArch>
    CPU_CONSTT_BR_EN    : boolean := false;
    CPU_FAST_MUL_EN     : boolean := false;
    CPU_FAST_SHIFT_EN   : boolean := false;
    CPU_RF_ARCH_SEL     : natural range 0 to 3 := 0;
    -- </MicroArch>
    -- <PMP>
    PMP_NUM_REGIONS     : natural range 0 to 16 := 0;
    PMP_MIN_GRANULARITY : natural := 4;
    PMP_TOR_MODE_EN     : boolean := false;
    PMP_NAP_MODE_EN     : boolean := false;
    -- </PMP>
    -- HPM ---------------------------------------------------------------------
    HPM_NUM_CNTS        : natural range 0 to 29 := 0;
    HPM_CNT_WIDTH       : natural range 0 to 64 := 64
    -- </main>
  );
  port (
    clk_i  : in  std_ulogic;
    rstn_i : in  std_ulogic;

    -- Observable output for synthesis/Odatix.
    gpio_o : out std_ulogic_vector(31 downto 0)
  );
end entity neorv32_wrapper;


architecture rtl of neorv32_wrapper is
  attribute keep_hierarchy : string;
  attribute keep_hierarchy of rtl : architecture is "yes";
  begin

  neorv32_top_inst : entity work.neorv32_top
    generic map (
      -- General ---------------------------------------------------------------
      CLOCK_FREQUENCY => 0,
      TRACE_PORT_EN   => false,
      DUAL_CORE_EN    => false,

      -- Boot from custom address ---------------------------------------------
      BOOT_MODE_SELECT => 1,
      BOOT_ADDR_CUSTOM => BOOT_ADDR,

      -- Debug disabled --------------------------------------------------------
      OCD_EN              => false,
      OCD_NUM_HW_TRIGGERS => 0,
      OCD_AUTHENTICATION  => false,

      -- ISA -------------------------------------------------------------------
      RISCV_ISA_C         => RISCV_ISA_C,
      RISCV_ISA_E         => RISCV_ISA_E,
      RISCV_ISA_M         => RISCV_ISA_M,
      RISCV_ISA_U         => RISCV_ISA_U,
      RISCV_ISA_Zmmul     => RISCV_ISA_Zmmul,

      RISCV_ISA_Zaamo     => RISCV_ISA_Zaamo,
      RISCV_ISA_Zalrsc    => RISCV_ISA_Zalrsc,

      RISCV_ISA_Zba       => RISCV_ISA_Zba,
      RISCV_ISA_Zbb       => RISCV_ISA_Zbb,
      RISCV_ISA_Zbc       => RISCV_ISA_Zbc,
      RISCV_ISA_Zbs       => RISCV_ISA_Zbs,
      RISCV_ISA_Zcb       => RISCV_ISA_Zcb,

      RISCV_ISA_Zbkb      => RISCV_ISA_Zbkb,
      RISCV_ISA_Zbkc      => RISCV_ISA_Zbkc,
      RISCV_ISA_Zbkx      => RISCV_ISA_Zbkx,
      RISCV_ISA_Zfinx     => RISCV_ISA_Zfinx,
      RISCV_ISA_Zibi      => RISCV_ISA_Zibi,
      RISCV_ISA_Zicntr    => RISCV_ISA_Zicntr,
      RISCV_ISA_Zicond    => RISCV_ISA_Zicond,
      RISCV_ISA_Zihpm     => RISCV_ISA_Zihpm,
      RISCV_ISA_Zimop     => RISCV_ISA_Zimop,
      RISCV_ISA_Zknd      => RISCV_ISA_Zknd,
      RISCV_ISA_Zkne      => RISCV_ISA_Zkne,
      RISCV_ISA_Zknh      => RISCV_ISA_Zknh,
      RISCV_ISA_Zksed     => RISCV_ISA_Zksed,
      RISCV_ISA_Zksh      => RISCV_ISA_Zksh,
      RISCV_ISA_Smcntrpmf => RISCV_ISA_Smcntrpmf,
      RISCV_ISA_Xcfu      => RISCV_ISA_Xcfu,

      -- Microarchitecture -----------------------------------------------------
      CPU_CONSTT_BR_EN  => CPU_CONSTT_BR_EN,
      CPU_FAST_MUL_EN   => CPU_FAST_MUL_EN,
      CPU_FAST_SHIFT_EN => CPU_FAST_SHIFT_EN,
      CPU_RF_ARCH_SEL   => CPU_RF_ARCH_SEL,

      -- PMP -------------------------------------------------------------------
      PMP_NUM_REGIONS     => PMP_NUM_REGIONS,
      PMP_MIN_GRANULARITY => PMP_MIN_GRANULARITY,
      PMP_TOR_MODE_EN     => PMP_TOR_MODE_EN,
      PMP_NAP_MODE_EN     => PMP_NAP_MODE_EN,

      -- HPM -------------------------------------------------------------------
      HPM_NUM_CNTS  => HPM_NUM_CNTS,
      HPM_CNT_WIDTH => HPM_CNT_WIDTH,

      -- Official internal memories -------------------------------------------
      IMEM_EN        => true,
      IMEM_BASE      => x"00000000",
      IMEM_SIZE      => 16*1024,
      IMEM_OUTREG_EN => false,

      DMEM_EN        => true,
      DMEM_BASE      => x"80000000",
      DMEM_SIZE      => 8*1024,
      DMEM_OUTREG_EN => false,

      -- Caches disabled: benchmark CPU + simple internal memories -------------
      ICACHE_EN         => false,
      DCACHE_EN         => false,
      CACHE_BURSTS_EN   => false,

      -- No external memory bus ------------------------------------------------
      XBUS_EN          => false,
      XBUS_REGSTAGE_EN => false,

      -- Minimal observable GPIO peripheral -----------------------------------
      IO_GPIO_NUM    => 1,
      IO_GPIO_DIR_EN => false,

      -- Other SoC peripherals disabled ---------------------------------------
      IO_CLINT_EN     => false,
      IO_UART0_EN     => false,
      IO_UART1_EN     => false,
      IO_SPI_EN       => false,
      IO_SDI_EN       => false,
      IO_TWI_EN       => false,
      IO_TWD_EN       => false,
      IO_PWM_NUM      => 0,
      IO_WDT_EN       => false,
      IO_TRNG_EN      => false,
      IO_CFS_EN       => false,
      IO_NEOLED_EN    => false,
      IO_GPTMR_NUM    => 0,
      IO_ONEWIRE_EN   => false,
      IO_DMA_EN       => false,
      IO_SLINK_EN     => false,
      IO_TRACER_EN    => false,
      IO_TRACER_SIMLOG_EN => false
    )
    port map (
      -- Global ---------------------------------------------------------------
      clk_i      => clk_i,
      rstn_i     => rstn_i,
      rstn_ocd_o => open,
      rstn_wdt_o => open,

      -- Trace ----------------------------------------------------------------
      trace_cpu0_o => open,
      trace_cpu1_o => open,

      -- JTAG -----------------------------------------------------------------
      jtag_tck_i => '0',
      jtag_tdi_i => '0',
      jtag_tdo_o => open,
      jtag_tms_i => '0',

      -- XBUS -----------------------------------------------------------------
      xbus_adr_o => open,
      xbus_dat_o => open,
      xbus_cti_o => open,
      xbus_tag_o => open,
      xbus_we_o  => open,
      xbus_sel_o => open,
      xbus_stb_o => open,
      xbus_cyc_o => open,
      xbus_dat_i => (others => '0'),
      xbus_ack_i => '0',
      xbus_err_i => '0',

      -- Stream Link ----------------------------------------------------------
      slink_rx_dat_i => (others => '0'),
      slink_rx_src_i => (others => '0'),
      slink_rx_val_i => '0',
      slink_rx_lst_i => '0',
      slink_rx_rdy_o => open,
      slink_tx_dat_o => open,
      slink_tx_dst_o => open,
      slink_tx_val_o => open,
      slink_tx_lst_o => open,
      slink_tx_rdy_i => '0',

      -- GPIO -----------------------------------------------------------------
      gpio_dir_o => open,
      gpio_o     => gpio_o,
      gpio_i     => (others => '0'),

      -- UART0 ----------------------------------------------------------------
      uart0_txd_o  => open,
      uart0_rxd_i  => '1',
      uart0_rtsn_o => open,
      uart0_ctsn_i => '0',

      -- UART1 ----------------------------------------------------------------
      uart1_txd_o  => open,
      uart1_rxd_i  => '1',
      uart1_rtsn_o => open,
      uart1_ctsn_i => '0',

      -- SPI ------------------------------------------------------------------
      spi_clk_o => open,
      spi_dat_o => open,
      spi_dat_i => '0',
      spi_csn_o => open,

      -- SDI ------------------------------------------------------------------
      sdi_clk_i => '0',
      sdi_dat_o => open,
      sdi_dat_i => '0',
      sdi_csn_i => '1',

      -- TWI ------------------------------------------------------------------
      twi_sda_i => '1',
      twi_sda_o => open,
      twi_scl_i => '1',
      twi_scl_o => open,

      -- TWD ------------------------------------------------------------------
      twd_sda_i => '1',
      twd_sda_o => open,
      twd_scl_i => '1',

      -- 1-Wire ---------------------------------------------------------------
      onewire_i => '1',
      onewire_o => open,

      -- PWM ------------------------------------------------------------------
      pwm_o => open,

      -- CFS ------------------------------------------------------------------
      cfs_in_i  => (others => '0'),
      cfs_out_o => open,

      -- NeoLED ---------------------------------------------------------------
      neoled_o => open,

      -- CLINT time -----------------------------------------------------------
      mtime_time_o => open,

      -- External IRQs --------------------------------------------------------
      irq_msi_i => '0',
      irq_mti_i => '0',
      irq_mei_i => '0'
    );

end architecture rtl;