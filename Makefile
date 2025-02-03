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
CPU = qemu64
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
OPTIMIZATION = 	-falign-functions=16 -falign-jumps=16 -falign-loops=16 \
								-fauto-inc-dec -fcprop-registers -fdce -fdefer-pop \
								-fno-strict-aliasing -fno-tree-dse -fno-tree-fre \
								-fno-rename-registers -fno-prefetch-loop-arrays \
								-fcompare-elim -fcprop-registers -fdce -fdefer-pop \
								-fdse -fforward-propagate -fif-conversion -fif-conversion2 \
								-fipa-modref -fipa-profile -fipa-pure-const -fipa-reference \
								-fipa-reference-addressable -fmove-loop-invariants \
								-fno-reorder-blocks -fshrink-wrap-separate -fsplit-wide-types \
								-fssa-backprop -fssa-phiopt -ftree-bit-ccp -ftree-ccp \
								-ftree-ch -ftree-coalesce-vars -ftree-copy-prop -ftree-dce \
								-ftree-dominator-opts -ftree-forwprop -ftree-phiprop \
								-ftree-pta -ftree-scev-cprop -ftree-sink -ftree-slsr -fno-inline \
								-ftree-sra -ftree-ter -funit-at-a-time -fno-omit-frame-pointer \
								-falign-functions -falign-jumps -fcaller-saves -fcrossjumping \
								-fcse-follow-jumps -fcse-skip-blocks -fdelete-null-pointer-checks \
								-fdevirtualize -fdevirtualize-speculatively  -fcode-hoisting \
								-fgcse -fgcse-lm  -fhoist-adjacent-loads -finline-small-functions \
								-findirect-inlining -fipa-cp -fipa-bit-cp -fipa-vrp -fipa-sra \
								-fipa-icf -fisolate-erroneous-paths-dereference -flra-remat \
								-foptimize-sibling-calls -foptimize-strlen -fpartial-inlining \
								-fpeephole2 -freorder-blocks-algorithm=stc -ftree-tail-merge \
								-freorder-blocks-and-partition -freorder-functions  -fipa-ra \
								-frerun-cse-after-loop  -fsched-interblock  -ftree-vrp -ffixed-rax \
								-fsched-spec -fschedule-insns -fschedule-insns2 -fstore-merging \
								-fstrict-aliasing -fstrict-overflow -ftree-builtin-call-dce \
								-ftree-switch-conversion -ftree-pre -fexpensive-optimizations

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
	bash createBootable.sh

# Run the final image using QEMU
run: $(OUTPUT) $(BOOT_IMG)
	$(QEMU) -drive file=$(BOOT_IMG),format=raw -m $(MEM) -smp $(CORES) \
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
