# This makefile is used to build bare-metal binaries for x86 devices to run on QEMU
# Author: Darshan(@thisisthedarshan) <darshanp@vayavyalabs.com> 
# Simply run the command `make` to run this file. It generates a x86-bare.dsp file
# which is the .c files compiled to run on x86 QEMU. Check the README of this repo
# for more information.

# File names
ASM_SRC = start.s
ASM_OBJ = start.o
C_SRCS = $(shell find . -name "*.c") # Collect all .c files in all the directories
C_OBJS = $(C_SRCS:.c=.o)       # Convert .c files to .o files

# Output binary
OUTPUT = x86-bare.dsp
BOOT_IMG = boot.dsp

# Compiler and tools
CC = gcc
LD = ld
AS = as

# QEMU and Its Arguments
QEMU = qemu-system-x86_64
MEM = 1.2G # For 1 GB Memory
CORES = 1 # For single core - max 4 cores recommended
QEMU_GDB = -s -S # GDB Flags - No need to keep if not required
XHCI_PCI_ADDR = 05.0 # Bus 0, Device 5, Function 0
LOGFILE=./x86.log

# Compiler flags
OPTIMIZATION = -O0 # 0 - No, 2 -Better
CFLAGS = -ffreestanding -fcf-protection=none -mno-shstk -fno-PIE \
         -nostartfiles -nostdlib -Wall $(OPTIMIZATION) -m64 -ggdb3 -std=gnu99 \
         -I. $(shell find . -type d -not -path '*/\.*' -exec echo -I{} \;)

LDFLAGS = -m elf_x86_64 $(OPTIMIZATION) -nostdlib -g -T x86D.ld -o $(OUTPUT)

ASFLAGS = -ggdb3 --64 $(ASM_SRC) -o $(ASM_OBJ)


# Default target to build the binary
all: $(OUTPUT)
	bash createBootable.sh

# Rule to compile assembly file into an object file
$(ASM_OBJ): $(ASM_SRC)
	$(CC) $(CFLAGS) -c $< -o $@

# Rule to compile C files into object files
$(C_OBJS): %.o: %.c
	$(CC) $(CFLAGS) -DPERSPEC_HW -c $< -o $@

# Rule to link object files into an ELF binary
$(OUTPUT): $(ASM_OBJ) $(C_OBJS)
	$(LD) $(LDFLAGS) $(ASM_OBJ) $(C_OBJS)

# Run the final image using QEMU
run: $(OUTPUT)
	$(QEMU) -drive file=$(BOOT_IMG),format=raw -m $(MEM) -smp $(CORES) \
		 			-cpu qemu64 -no-reboot $(QEMU_GDB) \
					-device qemu-xhci,addr=$(XHCI_PCI_ADDR) \
					-d guest_errors,trace:usb_xhci*,trace:usb_dwc* -D $(LOGFILE)

# Clean up the generated files
clean:
	rm -f $(ASM_OBJ) $(C_OBJS) $(OUTPUT)

qemu: run

test: run

# Phony targets
.PHONY: all clean run
