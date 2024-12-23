# This makefile is used to build bare-metal binaries for x86 devices to run on QEMU
# Author: Darshan(@thisisthedarshan) <darshanp@vayavyalabs.com> 
# Simply run the command `make` to run this file. It generates a x86-bare.bin file
# which is the .c files compiled to run on x86 QEMU. Check the README of this repo
# for more information.

# File names
ASM_SRC = start.s
ASM_OBJ = start.o
C_SRC = $(wildcard *.c)      # Collect all .c files in the directory
C_OBJ = $(C_SRC:.c=.o)       # Convert .c files to .o files

# Output binary
OUTPUT = x86-bare.dsp

# Compiler and tools
CC = gcc
LD = ld
OBJCOPY = objcopy
QEMU = qemu-system-x86_64

# Compiler flags
CFLAGS = -ffreestanding -fno-PIE -nostartfiles -nostdlib -Wall -O2 -m64 -ggdb3
LDFLAGS = -m elf_x86_64 -T x86D.ld -o $(OUTPUT)

# Default target to build the binary
all: $(OUTPUT)

# Rule to compile assembly file into an object file
$(ASM_OBJ): $(ASM_SRC)
	$(CC) $(CFLAGS) -c $< -o $@

# Rule to compile C files into object files
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Rule to link object files into an ELF binary
$(OUTPUT): $(ASM_OBJ) $(C_OBJ)
	$(LD) $(LDFLAGS) $(ASM_OBJ) $(C_OBJ)

# Run the final image using QEMU
run: $(OUTPUT)
	$(QEMU) -kernel $(OUTPUT) -device pci-xhci,addr=00.0,mmio=0xED69420 -m 1G -bios none -cpu qemu64 -smp 1 -no-reboot

# Clean up the generated files
clean:
	rm -f $(ASM_OBJ) $(C_OBJ) x86-bare.elf $(OUTPUT)

# Phony targets
.PHONY: all clean run
