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
QEMU = qemu-system-i386
CPU = qemu32
MEM = 1.2G # For 3 GB Memory
CORES = 1 # For single core - max 4 cores recommended
QEMU_GDB = -s -S # GDB Flags - No need to keep if not required
DISP =# This is for -nographic flag - added when using make DISPLAY=-nographic run
DEVICES =# For devices attached
XHCI_PCI_ADDR = 05.0 # Bus 0, Device 5, Function 0
LOGFILE=./x86.log

# Compiler flags
GDB = -ggdb3
TUNE = -mtune=generic #-march=generic
OPTIMIZATIONS = # Nothing

CFLAGS = -ffreestanding -fcf-protection=none -mno-shstk -fno-PIE \
         -nostartfiles -nostdlib -Wall $(OPTIMIZATION) -m32 \
				 $(GDB) -std=gnu99 $(TUNE) \
         -I. $(shell find . -type d -not -path '*/\.*' -exec echo -I{} \;)

LDFLAGS = -m elf_i386 -nostdlib -g -T x86D.ld -o $(OUTPUT)

ASFLAGS = $(GDB) --64 $(ASM_SRC) -o $(ASM_OBJ)


# Default target to build the binary
all: $(OUTPUT)

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
run: $(OUTPUT) $(BOOT_IMG)
	$(QEMU) -kernel $(OUTPUT) -m $(MEM) -smp $(CORES) \
		 			-cpu $(CPU) -no-reboot $(QEMU_GDB)$(DISP) \
					-device qemu-xhci,addr=$(XHCI_PCI_ADDR) $(DEVICES) \
					-d guest_errors,trace:usb_xhci*,trace:usb_dwc* -D $(LOGFILE)

# Clean up the generated files
clean:
	rm -f $(ASM_OBJ) $(C_OBJS) $(OUTPUT)

qemu: run

test: run

# Phony targets
.PHONY: all clean run
