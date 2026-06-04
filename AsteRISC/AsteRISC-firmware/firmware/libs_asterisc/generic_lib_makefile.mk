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
MARCH      = -march=rv32i -mabi=ilp32
CFLAGS     = -Wall -O3 -pedantic $(MARCH) -DPRINTF_DISABLE_SUPPORT_FLOAT -DPRINTF_DISABLE_SUPPORT_EXPONENTIAL -DPRINTF_DISABLE_SUPPORT_LONG_LONG #-fno-exceptions -fno-asynchronous-unwind-tables -fno-ident 

########################################################
# Toolchain path 
########################################################

# Edit riscv_env to set your RISCV toolchain path
include ../../riscv_env
export RISCV_DIR RISCV_BIN RISCV_TT RISCV_LIB RISCV_INC RISCV_GCC_LIB

CC         = $(RISCV_BIN)/$(RISCV_TT)-gcc
AR         = $(RISCV_BIN)/$(RISCV_TT)-ar

########################################################
# Folders
########################################################
INCDIR     = include
SRCDIR     = source
OBJDIR     = rv32i/obj
ARDIR      = rv32i/ar

SOURCES   := $(wildcard $(SRCDIR)/*.c)
OBJECTS   := $(SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o)
ARCHIVES  := $(OBJECTS:$(OBJDIR)/%.o=$(ARDIR)/%.a)

########################################################
# Text Format
########################################################
_BOLD      =\x1b[1m
_END       =\x1b[0m

_BLUE      =\x1b[34m
_GREY      =\x1b[30m
_CYAN      =\x1b[36m
_YELLOW    =\x1b[33m
_GREEN     =\x1b[32m
_WHITE     =\x1b[37m
_BLACK     =\x1b[30m

_IBLUE     =\x1b[44m
_IGREY     =\x1b[40m
# _ARROW     =

INIT_LI    =0

########################################################
# Make rules
########################################################
ALL_LIBS   = $(ARDIR)/libasterisc.a $(ARDIR)/libdebug.a $(ARDIR)/libgpio.a $(ARDIR)/libuart.a $(ARDIR)/libuart_extensions.a $(ARDIR)/lib7seg.a $(ARDIR)/libspi_slave.a

.PHONY: all
all: $(ALL_LIBS)

# Libraries:
$(ARDIR)/libasterisc.a: $(SRCDIR)/asterisc.c $(INCDIR)/asterisc.h
	$(call compile_lib,asterisc,)

$(ARDIR)/libdebug.a: $(SRCDIR)/debug.c $(INCDIR)/debug.h
	$(call compile_lib,debug,)

$(ARDIR)/libgpio.a: $(SRCDIR)/gpio.c $(INCDIR)/gpio.h
	$(call compile_lib,gpio,$(OBJDIR)/asterisc.o)

$(ARDIR)/libuart.a: $(SRCDIR)/uart.c $(INCDIR)/uart.h
	$(call compile_lib,uart,$(OBJDIR)/asterisc.o)

$(ARDIR)/libuart_extensions.a: $(SRCDIR)/uart_extensions.c $(INCDIR)/uart_extensions.h
	$(call compile_lib,uart_extensions,$(OBJDIR)/asterisc.o $(OBJDIR)/uart.o)
 
$(ARDIR)/lib7seg.a: $(SRCDIR)/7seg.c $(INCDIR)/7seg.h
	$(call compile_lib,7seg,$(OBJDIR)/asterisc.o $(OBJDIR)/gpio.o)

$(ARDIR)/libspi_slave.a: $(SRCDIR)/spi_slave.c $(INCDIR)/spi_slave.h
	$(call compile_lib,spi_slave,$(OBJDIR)/asterisc.o)

# Compile lib$(1).a
define compile_lib
	@if [ $(INIT_LI) = 0 ]; then\
		/bin/echo -e "\n$(_IBLUE)$(_BLACK) building libraries $(_END)$(_BLUE)$(_ARROW)$(_END)";\
	fi
	@$(eval INIT_LI = 1)
	@mkdir -p $(ARDIR)
	@mkdir -p $(OBJDIR)
	@/bin/echo -e "building lib $(_BOLD)$(_YELLOW)$(1)$(_END)"
	@$(CC) $(CFLAGS) -c $(SRCDIR)/$(1).c -o $(OBJDIR)/$(1).o -I$(SRCDIR)
	@$(AR) rc -o $(ARDIR)/lib$(1).a $(OBJDIR)/$(1).o $(2)
endef
#	@/bin/echo -e " $(_GREEN)done$(_END)"

