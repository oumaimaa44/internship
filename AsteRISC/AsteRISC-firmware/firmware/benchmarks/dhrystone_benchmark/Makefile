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
TARGET     = dhrystone_benchmark
CFLAGS     = -O3 -march=rv32i -mabi=ilp32 -DTIME -DRISCV -DUSE_MYSTDLIB -ffreestanding -nostdlib
AFLAGS     = -march=rv32i -mabi=ilp32

IMEM_ADDR_BASE = 0xF0000000
DMEM_ADDR_BASE = 0x10000000

########################################################
# Toolchain path 
########################################################
RISCV_DIR   = /opt/riscv
CC         = $(RISCV_DIR)/bin/riscv32-unknown-elf-gcc
AS         = $(RISCV_DIR)/bin/riscv32-unknown-elf-as
LD         = $(RISCV_DIR)/bin/riscv32-unknown-elf-ld

LIBC_INC   =$(RISCV_DIR)/riscv32-unknown-elf/include/

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
OBJECTS    = $(OBJDIR)/dhry_1.o $(OBJDIR)/dhry_2.o $(OBJDIR)/stdlib.o

LDFLAGS    = -L$(LIBC_INC)

########################################################
# Make rules
########################################################
.PHONY: all
all: $(BINDIR)/$(TARGET)

$(BINDIR)/$(TARGET): $(OBJECTS) $(START)
	@$(LD) -Ttext $(IMEM_ADDR_BASE) -Tdata $(DMEM_ADDR_BASE) -T $(COMMONDIR)/riscv.ld $(START) $(OBJECTS) -o $(BINDIR)/$(TARGET) $(LDFLAGS) -lgcc
	@$(TOOLSDIR)/gen_mem.sh $(BINDIR)/$(TARGET)

$(START): $(DIR)/start.S
	@$(AS) -o $(OBJDIR)/start.o $(AFLAGS) $(DIR)/start.S
#	@$(AS) -o $@ $(CFLAGS) $<

$(OBJECTS): $(OBJDIR)/%.o: $(SRCDIR)/%.c
	@$(CC) -c -o $@ $(CFLAGS) $<

$(OBJDIR)/dhry_1.o $(OBJDIR)/dhry_2.o: CFLAGS += -Wno-implicit-int -Wno-implicit-function-declaration

-include *.d
