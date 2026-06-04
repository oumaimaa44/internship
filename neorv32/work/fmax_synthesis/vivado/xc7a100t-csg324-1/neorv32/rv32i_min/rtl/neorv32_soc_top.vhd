-- Parameterized NEORV32 wrapper for Odatix exploration.
-- Top entity for Odatix: neorv32_soc_top
-- Official NEORV32 files should be compiled in library "neorv32".

library ieee;
use ieee.std_logic_1164.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_soc_top is
  generic (	CLOCK_FREQUENCY : natural := 100_000_000;
	BOOT_MODE_SELECT : natural range 0 to 2 := 2;

	DUAL_CORE_EN        : boolean := false;
	RISCV_ISA_C         : boolean := false;
	RISCV_ISA_E         : boolean := false;
	RISCV_ISA_M         : boolean := false;
	RISCV_ISA_U         : boolean := false;
	RISCV_ISA_Zicntr    : boolean := true;
	RISCV_ISA_Zihpm     : boolean := false;
	RISCV_ISA_Zmmul     : boolean := false;
	RISCV_ISA_Zfinx     : boolean := false;
	RISCV_ISA_Zba       : boolean := false;
	RISCV_ISA_Zbb       : boolean := false;
	RISCV_ISA_Zbs       : boolean := false;
	CPU_FAST_MUL_EN     : boolean := false;
	CPU_FAST_SHIFT_EN   : boolean := false;
	CPU_RF_ARCH_SEL     : natural range 0 to 3 := 0;

	IMEM_EN             : boolean := true;
	IMEM_SIZE           : natural := 64*1024;
	IMEM_OUTREG_EN      : boolean := false;
	DMEM_EN             : boolean := true;
	DMEM_SIZE           : natural := 32*1024;
	DMEM_OUTREG_EN      : boolean := false;
	ICACHE_EN           : boolean := false;
	ICACHE_NUM_BLOCKS   : natural range 1 to 4096 := 4;
	DCACHE_EN           : boolean := false;
	DCACHE_NUM_BLOCKS   : natural range 1 to 4096 := 4;
	CACHE_BLOCK_SIZE    : natural range 4 to 1024 := 64;
	CACHE_BURSTS_EN     : boolean := true;

	XBUS_EN             : boolean := false;
	XBUS_REGSTAGE_EN    : boolean := false;

	IO_GPIO_NUM         : natural range 0 to 32 := 32;
	IO_GPIO_DIR_EN      : boolean := true;
	IO_UART0_EN         : boolean := false;
	IO_UART0_RX_FIFO    : natural range 1 to 2**15 := 1;
	IO_UART0_TX_FIFO    : natural range 1 to 2**15 := 1;
	IO_CLINT_EN         : boolean := false;
	IO_PWM_NUM          : natural range 0 to 32 := 0;
	IO_GPTMR_NUM        : natural range 0 to 16 := 0;
	IO_WDT_EN           : boolean := false;
   	IO_DMA_EN           : boolean := false;

    	DUMMY_LAST          : natural := 0
);
  port (
    clk_i       : in  std_ulogic;
    rstn_i      : in  std_ulogic;

    gpio_i      : in  std_ulogic_vector(31 downto 0) := (others => '0');
    gpio_o      : out std_ulogic_vector(31 downto 0);
    gpio_dir_o  : out std_ulogic_vector(31 downto 0)
  );
end entity neorv32_soc_top;

architecture rtl of neorv32_soc_top is
begin

  u_neorv32 : entity neorv32.neorv32_top
    generic map (
      -- General
      CLOCK_FREQUENCY   => CLOCK_FREQUENCY,
      TRACE_PORT_EN     => false,
      DUAL_CORE_EN      => DUAL_CORE_EN,

      -- Boot
      BOOT_MODE_SELECT  => BOOT_MODE_SELECT,

      -- Debug disabled for a small default configuration
      OCD_EN            => false,

      -- CPU / ISA
      RISCV_ISA_C       => RISCV_ISA_C,
      RISCV_ISA_E       => RISCV_ISA_E,
      RISCV_ISA_M       => RISCV_ISA_M,
      RISCV_ISA_U       => RISCV_ISA_U,
      RISCV_ISA_Zicntr  => RISCV_ISA_Zicntr,
      RISCV_ISA_Zihpm   => RISCV_ISA_Zihpm,
      RISCV_ISA_Zmmul   => RISCV_ISA_Zmmul,
      RISCV_ISA_Zfinx   => RISCV_ISA_Zfinx,
      RISCV_ISA_Zba     => RISCV_ISA_Zba,
      RISCV_ISA_Zbb     => RISCV_ISA_Zbb,
      RISCV_ISA_Zbs     => RISCV_ISA_Zbs,
      CPU_FAST_MUL_EN   => CPU_FAST_MUL_EN,
      CPU_FAST_SHIFT_EN => CPU_FAST_SHIFT_EN,
      CPU_RF_ARCH_SEL   => CPU_RF_ARCH_SEL,

      -- Internal memories
      IMEM_EN           => IMEM_EN,
      IMEM_SIZE         => IMEM_SIZE,
      IMEM_OUTREG_EN    => IMEM_OUTREG_EN,
      DMEM_EN           => DMEM_EN,
      DMEM_SIZE         => DMEM_SIZE,
      DMEM_OUTREG_EN    => DMEM_OUTREG_EN,

      -- Caches
      ICACHE_EN         => ICACHE_EN,
      ICACHE_NUM_BLOCKS => ICACHE_NUM_BLOCKS,
      DCACHE_EN         => DCACHE_EN,
      DCACHE_NUM_BLOCKS => DCACHE_NUM_BLOCKS,
      CACHE_BLOCK_SIZE  => CACHE_BLOCK_SIZE,
      CACHE_BURSTS_EN   => CACHE_BURSTS_EN,

      -- External bus
      XBUS_EN           => XBUS_EN,
      XBUS_REGSTAGE_EN  => XBUS_REGSTAGE_EN,

      -- Peripherals
      IO_GPIO_NUM       => IO_GPIO_NUM,
      IO_GPIO_DIR_EN    => IO_GPIO_DIR_EN,
      IO_UART0_EN       => IO_UART0_EN,
      IO_UART0_RX_FIFO  => IO_UART0_RX_FIFO,
      IO_UART0_TX_FIFO  => IO_UART0_TX_FIFO,
      IO_CLINT_EN       => IO_CLINT_EN,
      IO_PWM_NUM        => IO_PWM_NUM,
      IO_GPTMR_NUM      => IO_GPTMR_NUM,
      IO_WDT_EN         => IO_WDT_EN,
      IO_DMA_EN         => IO_DMA_EN,

      -- Unused optional peripherals kept disabled
      IO_UART1_EN       => false,
      IO_SPI_EN         => false,
      IO_SDI_EN         => false,
      IO_TWI_EN         => false,
      IO_TWD_EN         => false,
      IO_TRNG_EN        => false,
      IO_CFS_EN         => false,
      IO_NEOLED_EN      => false,
      IO_ONEWIRE_EN     => false,
      IO_SLINK_EN       => false,
      IO_TRACER_EN      => false
    )
    port map (
      -- Global control
      clk_i          => clk_i,
      rstn_i         => rstn_i,
      rstn_ocd_o     => open,
      rstn_wdt_o     => open,

      -- Trace / debug disabled
      trace_cpu0_o   => open,
      trace_cpu1_o   => open,
      jtag_tck_i     => '0',
      jtag_tdi_i     => '0',
      jtag_tdo_o     => open,
      jtag_tms_i     => '0',

      -- External bus hidden at wrapper boundary
      xbus_adr_o     => open,
      xbus_dat_o     => open,
      xbus_cti_o     => open,
      xbus_tag_o     => open,
      xbus_we_o      => open,
      xbus_sel_o     => open,
      xbus_stb_o     => open,
      xbus_cyc_o     => open,
      xbus_dat_i     => (others => '0'),
      xbus_ack_i     => '0',
      xbus_err_i     => '0',

      -- Stream link disabled
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

      -- GPIO exposed
      gpio_dir_o     => gpio_dir_o,
      gpio_o         => gpio_o,
      gpio_i         => gpio_i,

      -- UART0 disabled
      uart0_txd_o    => open,
      uart0_rxd_i    => '1',
      uart0_rtsn_o   => open,
      uart0_ctsn_i   => '0',

      -- UART1 disabled
      uart1_txd_o    => open,
      uart1_rxd_i    => '1',
      uart1_rtsn_o   => open,
      uart1_ctsn_i   => '0',

      -- SPI disabled
      spi_clk_o      => open,
      spi_dat_o      => open,
      spi_dat_i      => '0',
      spi_csn_o      => open,

      -- SDI disabled
      sdi_clk_i      => '0',
      sdi_dat_o      => open,
      sdi_dat_i      => '0',
      sdi_csn_i      => '1',

      -- TWI/TWD disabled
      twi_sda_i      => '1',
      twi_sda_o      => open,
      twi_scl_i      => '1',
      twi_scl_o      => open,
      twd_sda_i      => '1',
      twd_sda_o      => open,
      twd_scl_i      => '1',

      -- Other optional IO hidden
      onewire_i      => '1',
      onewire_o      => open,
      pwm_o          => open,
      cfs_in_i       => (others => '0'),
      cfs_out_o      => open,
      neoled_o       => open,
      mtime_time_o   => open,

      -- External CPU interrupts unused
      irq_msi_i      => '0',
      irq_mti_i      => '0',
      irq_mei_i      => '0'
    );

end architecture rtl;
