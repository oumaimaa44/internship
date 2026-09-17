# Makefile for dhrystone benchmark adapted for the neorv32
#Edited : 02 Juin, 2026

MARCH = rv32imc_zicsr_zifencei

EFFORT = -O3

USER_FLAGS += -DTIME
USER_FLAGS += -DRISCV
USER_FLAGS += -DNEORV32
USER_FLAGS += -DUART0_SIM_MODE
USER_FLAGS += -Wno-implicit-int
USER_FLAGS += -Wno-implicit-function-declaration
USER_FLAGS += -Wno-return-type

USER_FLAGS += \
-Wl,--defsym,__neorv32_rom_size=64k \
-Wl,--defsym,__neorv32_rom_base=0x00000000

USER_FLAGS += \
-Wl,--defsym,__neorv32_ram_size=32k \
-Wl,--defsym,__neorv32_ram_base=0x80000000

APP_SRC += dhry_1.c
APP_SRC += dhry_2.c

NEORV32_HOME ?= ../../..

include $(NEORV32_HOME)/sw/common/common.mk