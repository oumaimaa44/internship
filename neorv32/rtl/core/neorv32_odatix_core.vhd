library ieee;
use ieee.std_logic_1164.all;

library work;
use work.neorv32_package.all;


entity neorv32_odatix_core is
  generic (
    BOOT_ADDR : std_ulogic_vector(31 downto 0) := x"00000000";

    -- ISA
    RISCV_ISA_C         : boolean := false;
    RISCV_ISA_E         : boolean := false;
    RISCV_ISA_M         : boolean := false;
    RISCV_ISA_U         : boolean := false;
    RISCV_ISA_Zmmul     : boolean := false;

    RISCV_ISA_Zaamo     : boolean := false;
    RISCV_ISA_Zalrsc    : boolean := false;

    -- Bit manipulation
    RISCV_ISA_Zba       : boolean := false;
    RISCV_ISA_Zbb       : boolean := false;
    RISCV_ISA_Zbc       : boolean := false;
    RISCV_ISA_Zbs       : boolean := false;
    RISCV_ISA_Zcb       : boolean := false;

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

    -- Microarchitecture
    CPU_CONSTT_BR_EN    : boolean := false;
    CPU_FAST_MUL_EN     : boolean := false;
    CPU_FAST_SHIFT_EN   : boolean := false;
    CPU_RF_ARCH_SEL     : natural range 0 to 3 := 0;

    -- PMP
    PMP_NUM_REGIONS     : natural range 0 to 16 := 0;
    PMP_MIN_GRANULARITY : natural := 4;
    PMP_TOR_MODE_EN     : boolean := false;
    PMP_NAP_MODE_EN     : boolean := false;

    -- HPM
    HPM_NUM_CNTS        : natural range 0 to 29 := 0;
    HPM_CNT_WIDTH       : natural range 0 to 64 := 64
  );

  port (
    clk_i  : in std_ulogic;
    rstn_i : in std_ulogic;

    -- Native NEORV32 XBUS memory interface
    xbus_adr_o : out std_ulogic_vector(31 downto 0);
    xbus_dat_o : out std_ulogic_vector(31 downto 0);
    xbus_cti_o : out std_ulogic_vector(2 downto 0);
    xbus_tag_o : out std_ulogic_vector(2 downto 0);
    xbus_we_o  : out std_ulogic;
    xbus_sel_o : out std_ulogic_vector(3 downto 0);
    xbus_stb_o : out std_ulogic;
    xbus_cyc_o : out std_ulogic;

    xbus_dat_i : in std_ulogic_vector(31 downto 0);
    xbus_ack_i : in std_ulogic;
    xbus_err_i : in std_ulogic
  );
end entity;


architecture rtl of neorv32_odatix_core is
begin

  u_neorv32 : entity work.neorv32_top
    generic map (
      -- No bootloader: execute directly from BOOT_ADDR
      CLOCK_FREQUENCY  => 0,
      TRACE_PORT_EN    => false,
      DUAL_CORE_EN     => false,

      BOOT_MODE_SELECT => 1,
      BOOT_ADDR_CUSTOM => BOOT_ADDR,

      -- Debug disabled
      OCD_EN              => false,
      OCD_NUM_HW_TRIGGERS => 0,
      OCD_AUTHENTICATION  => false,

      -- ISA
      RISCV_ISA_C         => RISCV_ISA_C,
      RISCV_ISA_E         => RISCV_ISA_E,
      RISCV_ISA_M         => RISCV_ISA_M,
      RISCV_ISA_U         => RISCV_ISA_U,
      RISCV_ISA_Zaamo     => RISCV_ISA_Zaamo,
      RISCV_ISA_Zalrsc    => RISCV_ISA_Zalrsc,

      RISCV_ISA_Zba       => RISCV_ISA_Zba,
      RISCV_ISA_Zbb       => RISCV_ISA_Zbb,
      RISCV_ISA_Zbc       => RISCV_ISA_Zbc,
      RISCV_ISA_Zbkb      => RISCV_ISA_Zbkb,
      RISCV_ISA_Zbkc      => RISCV_ISA_Zbkc,
      RISCV_ISA_Zbkx      => RISCV_ISA_Zbkx,
      RISCV_ISA_Zbs       => RISCV_ISA_Zbs,
      RISCV_ISA_Zcb       => RISCV_ISA_Zcb,

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
      RISCV_ISA_Zmmul     => RISCV_ISA_Zmmul,
      RISCV_ISA_Smcntrpmf => RISCV_ISA_Smcntrpmf,
      RISCV_ISA_Xcfu      => RISCV_ISA_Xcfu,

      -- Microarchitecture
      CPU_CONSTT_BR_EN    => CPU_CONSTT_BR_EN,
      CPU_FAST_MUL_EN     => CPU_FAST_MUL_EN,
      CPU_FAST_SHIFT_EN   => CPU_FAST_SHIFT_EN,
      CPU_RF_ARCH_SEL     => CPU_RF_ARCH_SEL,

      -- PMP
      PMP_NUM_REGIONS     => PMP_NUM_REGIONS,
      PMP_MIN_GRANULARITY => PMP_MIN_GRANULARITY,
      PMP_TOR_MODE_EN     => PMP_TOR_MODE_EN,
      PMP_NAP_MODE_EN     => PMP_NAP_MODE_EN,

      -- HPM
      HPM_NUM_CNTS        => HPM_NUM_CNTS,
      HPM_CNT_WIDTH       => HPM_CNT_WIDTH,

      -- No internal memories
      IMEM_EN             => false,
      DMEM_EN             => false,

      -- No NEORV32 caches for this baseline
      ICACHE_EN           => false,
      DCACHE_EN           => false,

      -- Native external memory interface
      XBUS_EN             => true,
      XBUS_TIMEOUT        => 0,
      XBUS_REGSTAGE_EN    => false,

      -- No peripherals
      IO_GPIO_NUM         => 0,
      IO_CLINT_EN         => false,
      IO_UART0_EN         => false,
      IO_UART1_EN         => false,
      IO_SPI_EN           => false,
      IO_SDI_EN           => false,
      IO_TWI_EN           => false,
      IO_TWD_EN           => false,
      IO_PWM_NUM          => 0,
      IO_WDT_EN           => false,
      IO_TRNG_EN          => false,
      IO_CFS_EN           => false,
      IO_NEOLED_EN        => false,
      IO_GPTMR_NUM        => 0,
      IO_ONEWIRE_EN       => false,
      IO_DMA_EN           => false,
      IO_SLINK_EN         => false,
      IO_TRACER_EN        => false
    )

    port map (
      clk_i  => clk_i,
      rstn_i => rstn_i,

      rstn_ocd_o   => open,
      rstn_wdt_o   => open,

      trace_cpu0_o => open,
      trace_cpu1_o => open,

      -- Debug disabled
      jtag_tck_i => '0',
      jtag_tdi_i => '0',
      jtag_tdo_o => open,
      jtag_tms_i => '0',

      -- Native memory bus
      xbus_adr_o => xbus_adr_o,
      xbus_dat_o => xbus_dat_o,
      xbus_cti_o => xbus_cti_o,
      xbus_tag_o => xbus_tag_o,
      xbus_we_o  => xbus_we_o,
      xbus_sel_o => xbus_sel_o,
      xbus_stb_o => xbus_stb_o,
      xbus_cyc_o => xbus_cyc_o,

      xbus_dat_i => xbus_dat_i,
      xbus_ack_i => xbus_ack_i,
      xbus_err_i => xbus_err_i,

      -- Disabled SLINK
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

      -- Disabled GPIO
      gpio_dir_o => open,
      gpio_o     => open,
      gpio_i     => (others => '0'),

      -- Disabled UART0
      uart0_txd_o  => open,
      uart0_rxd_i  => '0',
      uart0_rtsn_o => open,
      uart0_ctsn_i => '0',

      -- Disabled UART1
      uart1_txd_o  => open,
      uart1_rxd_i  => '0',
      uart1_rtsn_o => open,
      uart1_ctsn_i => '0',

      -- Disabled SPI
      spi_clk_o => open,
      spi_dat_o => open,
      spi_dat_i => '0',
      spi_csn_o => open,

      -- Disabled SDI
      sdi_clk_i => '0',
      sdi_dat_o => open,
      sdi_dat_i => '0',
      sdi_csn_i => '1',

      -- Disabled TWI
      twi_sda_i => '1',
      twi_sda_o => open,
      twi_scl_i => '1',
      twi_scl_o => open,

      -- Disabled TWD
      twd_sda_i => '1',
      twd_sda_o => open,
      twd_scl_i => '1',

      -- Disabled 1-wire
      onewire_i => '1',
      onewire_o => open,

      -- Disabled PWM
      pwm_o => open,

      -- Disabled CFS
      cfs_in_i  => (others => '0'),
      cfs_out_o => open,

      -- Disabled NEOLED
      neoled_o => open,

      -- CLINT disabled
      mtime_time_o => open,

      -- No interrupts
      irq_msi_i => '0',
      irq_mti_i => '0',
      irq_mei_i => '0'
    );

end architecture;
