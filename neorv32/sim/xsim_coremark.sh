#!/bin/bash

set -e

cd ~/neorv32

rm -rf xsim.dir *.jou *.log *.pb webtalk*

echo "Compiling NEORV32 package..."
xvhdl --2008 --work neorv32 rtl/core/neorv32_package.vhd

echo "Compiling NEORV32 primitive files..."
for f in rtl/core/neorv32_prim*.vhd; do
  xvhdl --2008 --work neorv32 "$f"
done

echo "Compiling NEORV32 core files..."
for f in rtl/core/*.vhd; do
  base=$(basename "$f")

  if [ "$base" != "neorv32_package.vhd" ] && \
     [[ "$base" != neorv32_prim* ]] && \
     [ "$base" != "neorv32_top.vhd" ] && \
     [ "$base" != "neorv32_soc_top.vhd" ]; then
    xvhdl --2008 --work neorv32 "$f"
  fi
done

echo "Compiling official NEORV32 top last..."
xvhdl --2008 --work neorv32 rtl/core/neorv32_top.vhd

echo "Compiling simulation files..."
xvhdl --2008 --work work sim/jtag_dmi_pkg.vhd
xvhdl --2008 --work work sim/sim_uart_rx.vhd
xvhdl --2008 --work work sim/xbus_gateway.vhd
xvhdl --2008 --work work sim/xbus_memory.vhd
xvhdl --2008 --work work sim/xbus_fmem.vhd
xvhdl --2008 --work work sim/neorv32_tb.vhd

echo "Elaborating testbench..."
xelab --debug typical work.neorv32_tb -s neorv32_tb_sim

echo "run 100 ms" > sim/xsim_run.tcl
echo "quit" >> sim/xsim_run.tcl

echo "Running simulation..."
xsim neorv32_tb_sim -tclbatch sim/xsim_run.tcl
