# Assembly code for x86 Machine start code.
# Author: Darshan(@thisisthedarshan) <darshanp@vayavyalabs.com>
# This assembly code is used to boot the bare-metal QEMU system to enable us to
# run custom C code. The assembly code also includes test for qemu xHCI device
# connected on PCI bus 
# The C code is generated using GCC's x86 build tools. The Makefile is included
# to build the image file that can be run on QEMU's x86 system..
# The Assembly code is designed with multi-boot compliance

.set ALIGN,    1<<0             # align loaded modules on page boundaries
.set MEMINFO,  1<<1             # provide memory map
.set FLAGS,    ALIGN | MEMINFO  # this is the Multiboot 'flag' field
.set MAGIC,    0x1BADB002       # 'magic number' lets bootloader find the header
.set CHECKSUM, -(MAGIC + FLAGS) # checksum of above, to prove we are multiboot
.section .multiboot
.align 4
.global _boot_grub
_boot_grub:
    .long MAGIC
    .long FLAGS
    .long CHECKSUM
# Multiboot headers - setup done


# PCI xHCI Related Info
# QEMU Specific PCI Base Address
.set PCI_DEVICE_ADDRESS_BASE, 0x80000000

# Bus Number of the connected xHCI device
.set xHCI_BUS, 0
# Device Number
.set xHCI_DeviceNum, 5
# Function Number
.set xHCI_Function, 0

# xHCI Device Address without Register Offsets
.set xHCI_PCI_ADDR, PCI_DEVICE_ADDRESS_BASE | (xHCI_BUS << 16) | (xHCI_DeviceNum << 11) | (xHCI_Function << 8)

# Offsets of different Registers in PCI Space
.set PCI_VID_OFFSET, 0x00       # Vendor ID (16 bits)
.set PCI_DID_OFFSET, 0x02       # Device ID (16 bits)
.set PCI_CMD_OFFSET, 0x04       # Command Register (16 bits)
.set PCI_STATUS_OFFSET, 0x06    # Status Register (16 bits)
.set PCI_REV_ID_OFFSET, 0x08    # Revision ID (8 bits)
.set PCI_CLASS_CODE_OFFSET, 0x09 # Class Code (24 bits: Prog IF, Subclass, Base Class)
.set PCI_HEADER_TYPE, 0x0E      # Header Type (8 bits)
.set PCI_BIST, 0x0F             # Built-in Self-Test (8 bits)

.set PCI_BAR_0_OFFSET, 0x10     # Base Address Register 0 (32 bits or 64 bits)
.set PCI_BAR_1_OFFSET, 0x14     # Base Address Register 1 (32 bits or 64 bits)


# Final Calculated Addresses
.set xHCI_VID_ADDR,  xHCI_PCI_ADDR | PCI_VID_OFFSET
.set xHCI_DID_ADDR,  xHCI_PCI_ADDR | PCI_DID_OFFSET
.set xHCI_BAR0_ADDR, xHCI_PCI_ADDR | PCI_BAR_0_OFFSET
.set xHCI_BAR1_ADDR, xHCI_PCI_ADDR | PCI_BAR_1_OFFSET
.set xHCI_CMDR_ADDR, xHCI_PCI_ADDR | PCI_CMD_OFFSET
.set xHCI_HEAD_ADDR, xHCI_PCI_ADDR | PCI_HEADER_TYPE

# Macro to test value at a particular PCI address - result is in eax register
.macro read_pci addr
    movl \addr, %eax
    movw $0xCF8, %dx            # PCI configuration address register
    outl %eax, %dx              # Write to select PCI command register
    movw $0xCFC, %dx            # PCI configuration data register
    inl %dx, %eax               # Read PCI command register value
    mfence
.endm

# Start of main logic

.section .text
.global _start
.code32
_start:
    cli                        # Disable interrupts

    xor %ebp, %ebp             # Clear EBP
    mov $__stack_top, %esp     # Set up the stack
    mov %esp, %ebp

    fninit                      # FPU init

    # Enable protected mode
    mov %cr0, %eax
    or $0x1, %eax              # Set the PE bit
    mov %eax, %cr0

    mov $0x10, %ax             # Load data selector into segments
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    # mov %ax, %ss

    # Enable Long Mode
    movl $0xC0000080, %ecx     # Load EFER MSR
    rdmsr
    orl $0x00000100, %eax      # Set LME (Long Mode Enable)
    wrmsr

    lgdt gdt_descriptor_64        # Load the GDT

    mov %cr4, %eax
    or $0x20, %eax             # Enable PAE (Physical Address Extension)
    mov %eax, %cr4

    # Invalidate the cache after disabling caching
    invd                      # Invalidate the internal cache

.code64
start_main:
    mov $__stack_top, %rsp     # Set up 64-bit stack
    xor %rbp, %rbp

# Call C main function
    call main

.code32
end:
    # Load the value 0x2000 into the AX register
    movw $0x2000, %ax       # Load 0x2000 into AX register
    # Load destination on dx register
    movw $0x604, %dx
    # Send the value in AX to port 0x604 using the 'out' instruction
    outw %ax, %dx        # Write the value in AX to port 0x604
    hlt

# GDT Section
.section .rodata
.align 4096

gdt_64:
    .quad 0x0000000000000000  # Null descriptor
    .quad 0x00AF9A000000FFFF  # Code segment: Present, G=1, L=1, DPL=0, executable
    .quad 0x00AF92000000FFFF  # Data segment: Present, G=1, writable

gdt_descriptor_64:
    .word (gdt_end_64 - gdt_64 - 1)
    .quad gdt_64
gdt_end_64:
