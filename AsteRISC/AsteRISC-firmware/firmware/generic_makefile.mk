#**********************************************************************#
#                               AsteRISC                               #
#**********************************************************************#
#
# Copyright (C) 2022 Jonathan Saussereau
#
# This file is part of AsteRISC.
# AsteRISC is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# AsteRISC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with AsteRISC. If not, see <https://www.gnu.org/licenses/>.
#

########################################################
# Build settings
########################################################
TARGET     = my_example
LIBS       = -lasterisc
AFLAGS     = -march=rv32i -mabi=ilp32
MARCH  	   = -march=rv32i -mabi=ilp32
CFLAGS     = -Wall -O2 -pedantic $(MARCH) -MMD -MP #-fno-exceptions -fno-asynchronous-unwind-tables -fno-ident
RV32E      = 0

IMEM_ADDR_BASE = 0xF0000000
DMEM_ADDR_BASE = 0x10000000

########################################################
# Toolchain path 
########################################################

# Edit riscv_env to set your RISCV toolchain path
include ../../../riscv_env
export RISCV_DIR RISCV_BIN RISCV_TT RISCV_LIB RISCV_INC RISCV_GCC_LIB

CC         = $(RISCV_BIN)/$(RISCV_TT)-gcc
AS         = $(RISCV_BIN)/$(RISCV_TT)-as
LD         = $(RISCV_BIN)/$(RISCV_TT)-ld

GCCVERSION = $(shell $(CC) --version | grep gcc | sed 's/^.* //g')
LIB_GCC    = $(RISCV_DIR)/lib/gcc/$(RISCV_TT)/$(GCCVERSION)/$(RISCV_GCC_LIB)
LIBC_NANO  = $(RISCV_LIB)/libc_nano.a
LIBC_INC   = $(RISCV_INC)

########################################################
# Folders
########################################################
DIR        = .
SRCDIR     = $(DIR)/src
OBJDIR     = $(DIR)/obj
BINDIR     = $(DIR)/bin
COMMONDIR  = $(DIR)/../..
TOOLSDIR   = $(COMMONDIR)/../tools
LIBDIR     = $(COMMONDIR)/libs_asterisc
INCDIR     = $(LIBDIR)/include
STARTDIR   = $(COMMONDIR)

########################################################
# Processing settings
########################################################

SOURCES   := $(wildcard $(SRCDIR)/*.c)
OBJECTS   := $(SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o)
DEPS      := $(OBJECTS:.o=.d)

ifeq "$(RV32E)" "0"
START      = $(OBJDIR)/start_rv32i.o
ARDIR      = $(LIBDIR)/rv32i/ar
else
START      = $(OBJDIR)/start_rv32e.o
ARDIR      = $(LIBDIR)/rv32e/ar
endif

LDFLAGS    = -L$(ARDIR) -L$(LIBC_INC) -L$(LIB_GCC)

########################################################
# Text formatting
########################################################
_BOLD	     =\x1b[1m
_END	     =\x1b[0m

_BLUE	     =\x1b[34m
_CYAN      =\x1b[36m
_YELLOW    =\x1b[33m
_GREEN     =\x1b[32m
_WHITE     =\x1b[37m
_BLACK     =\x1b[30m

_IBLUE     =\x1b[44m

# _ARROW     =

INIT_MSG   =0

########################################################
# Make rules
########################################################
.PHONY : all
all: dirmake $(BINDIR)/$(TARGET)
#	@/bin/echo -e "$(_GREEN)done$(_END)"

$(BINDIR)/$(TARGET): $(OBJECTS) $(START)
	@$(LD) -Ttext $(IMEM_ADDR_BASE) -Tdata $(DMEM_ADDR_BASE) -T $(COMMONDIR)/riscv.ld $(START) $(OBJECTS) -o $(BINDIR)/$(TARGET) $(LIBC_NANO) $(LDFLAGS) $(LIBS)
	@/bin/bash -c '$(TOOLSDIR)/gen_mem.sh $(BINDIR)/$(TARGET)'
	@$(PYTHON3) $(TOOLSDIR)/hex2coe.py $(TARGET)

$(OBJDIR)/start_rv32i.o: $(STARTDIR)/start_rv32i.S
	@$(AS) -o $(OBJDIR)/start_rv32i.o $(AFLAGS) $(STARTDIR)/start_rv32i.S

$(OBJDIR)/start_rv32e.o: $(STARTDIR)/start_rv32e.S
	@$(AS) -o $(OBJDIR)/start_rv32e.o $(AFLAGS) $(STARTDIR)/start_rv32e.S

$(OBJECTS): $(OBJDIR)/%.o : $(SRCDIR)/%.c $(ARDIR)/*.a
	$(call message)
	@$(CC) $(CFLAGS) -c $< -o $@ -I$(INCDIR) -I$(LIBC_INC) -I$(RISCV_DIR)/lib/gcc/riscv32-unknown-elf/$(GCCVERSION)/include

-include $(DEPS)

define message
	@if [ $(INIT_MSG) = 0 ]; then\
		/bin/echo "";\
		/bin/echo -e "$(_IBLUE)$(_BLACK) building $(_YELLOW)$(_BOLD)$(TARGET) $(_END)$(_BLUE)$(_ARROW)$(_END)";\
	fi
	@$(eval INIT_MSG = 1)
endef

.PHONY: clean
clean: 
	@rm -f $(OBJDIR)/*.o $(OBJDIR)/$(TARGET)

.PHONY: remove
remove: clean
	@rm -f $(BINDIR)/$(TARGET)

.PHONY: dirmake
dirmake:
	@mkdir -p $(BINDIR)
	@mkdir -p $(OBJDIR)

