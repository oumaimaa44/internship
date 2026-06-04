#
# Copyright(C) 2022 by Jonathan Saussereau. All rights reserved.
# 
# All source codes and documentation contain proprietary confidential
# information and are distributed under license. It may be used, copied
# and/or disclosed only pursuant to the terms of a valid license agreement
# with Jonathan Saussereau. This copyright must be retained at all times.
#
# Makefile
#

########################################################
# Build settings
########################################################
TARGET     = coremark_benchmark
CFLAGS     = -O3 -march=rv32im -mabi=ilp32 -DTIME -DRISCV -DUSE_MYSTDLIB -ffreestanding -nostdlib

IMEM_ADDR_BASE = 0xF0000000
DMEM_ADDR_BASE = 0x10000000

########################################################
# Toolchain path 
########################################################
RISCV_DIR   = /opt/riscv
TOOLCHAIN_PREFIX = $(RISCV_DIR)/bin/riscv32-unknown-elf-
CC         = $(TOOLCHAIN_PREFIX)gcc

########################################################
# Folders
########################################################
DIR        = .
SRCDIR     = $(DIR)/src
OBJDIR     = $(DIR)/obj
BINDIR     = $(DIR)/bin
COMMONDIR  = $(DIR)/..
TOOLSDIR   = $(COMMONDIR)/tools

########################################################
# Processing settings
########################################################
START      = $(OBJDIR)/start.o
OBJECTS    = $(OBJDIR)/core_list_join.o $(OBJDIR)/core_main.o $(OBJDIR)/core_matrix.o $(OBJDIR)/core_portme.o $(OBJDIR)/core_state.o $(OBJDIR)/core_util.o $(OBJDIR)/ee_printf.o
GCCVERSION = $(shell $(CC) --version | grep gcc | sed 's/^.* //g')
LIBGCC	   =$(RISCV_DIR)/lib/gcc/riscv32-unknown-elf/$(GCCVERSION)/rv32i/ilp32/
LDFLAGS    = -L$(LIBGCC)

########################################################
# Make rules
########################################################
.PHONY: all
all: $(BINDIR)/$(TARGET)

$(BINDIR)/$(TARGET): $(OBJECTS) $(START)
	$(TOOLCHAIN_PREFIX)ld -Ttext $(IMEM_ADDR_BASE) -Tdata $(DMEM_ADDR_BASE) -T $(COMMONDIR)/riscv.ld $(START) $(OBJECTS) -o $(BINDIR)/$(TARGET) $(LDFLAGS) -lgcc
	@$(TOOLSDIR)/gen_mem.sh $(BINDIR)/$(TARGET)

$(START): $(DIR)/start.S
	@$(TOOLCHAIN_PREFIX)gcc -c -o $@ $(CFLAGS) $<

$(OBJECTS): $(OBJDIR)/%.o: $(SRCDIR)/%.c
	@$(TOOLCHAIN_PREFIX)gcc -c -o $@ $(CFLAGS) $<

$(OBJDIR)/dhry_1.o $(OBJDIR)/dhry_2.o: CFLAGS += -Wno-implicit-int -Wno-implicit-function-declaration

-include *.d
