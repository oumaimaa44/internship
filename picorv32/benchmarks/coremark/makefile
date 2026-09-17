RISCV_PREFIX ?= riscv64-unknown-elf-

CC      = $(RISCV_PREFIX)gcc
OBJCOPY = $(RISCV_PREFIX)objcopy
OBJDUMP = $(RISCV_PREFIX)objdump

# PicoRV32 here is configured with fast mul/div, but not compressed C.
# So do NOT use rv32imc.
ARCH = rv32im
ABI  = ilp32

CFLAGS = -Os \
	-march=$(ARCH) -mabi=$(ABI) \
	-ffreestanding -nostdlib \
	-Iinclude -Isource \
	-DPERFORMANCE_RUN=1 \
	-DTOTAL_DATA_SIZE=2000 \
	-Wno-unused-parameter \
	-Wno-implicit-function-declaration

LDFLAGS = -Wl,-Bstatic,-T,sections.lds,--strip-debug \
	-nostdlib

COREMARK_SRCS = \
	start.S \
	source/stdlib.c \
	source/core_main.c \
	source/core_list_join.c \
	source/core_matrix.c \
	source/core_state.c \
	source/core_util.c \
	source/core_portme.c \
	source/ee_printf.c

COREMARK_OBJS = $(COREMARK_SRCS:.c=.o)
COREMARK_OBJS := $(COREMARK_OBJS:.S=.o)

all: testbench.vvp coremark.hex

testbench.vvp: testbench.v ../picorv32.v
	iverilog -o testbench.vvp testbench.v ../picorv32.v
	chmod -x testbench.vvp

coremark.elf: $(COREMARK_OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(COREMARK_OBJS) -lgcc

coremark.hex: coremark.elf
	$(OBJCOPY) -O verilog coremark.elf coremark.hex
	$(OBJDUMP) -D coremark.elf > coremark.dis

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

sim: all
	vvp -N testbench.vvp

clean:
	rm -f $(COREMARK_OBJS)
	rm -f coremark.elf coremark.hex coremark.dis
	rm -f testbench.vvp testbench.vcd testbench.trace
	rm -f *.o source/*.o