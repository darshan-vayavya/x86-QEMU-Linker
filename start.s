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

.section .text
.global _start
.code32
_start:
    cli
    mov $__stack_top, %esp
    mov %esp, %ebp
    fninit

    # Clear page tables for heap range
    mov $pml4_base, %edi
    mov $0x1D369000, %eax    # HEAP_START
    shr $39, %eax            # Get PML4 index
    shl $3, %eax             # Multiply by 8 (entry size)
    add %eax, %edi
    mov $((0x19969000 >> 39) + 1), %ecx  # Number of entries needed
    xor %eax, %eax
    rep stosl

    # Initialize page tables for heap
    mov $pml4_base, %edi
    mov $pdpt_base, %eax
    or $0x3, %eax            # Present + R/W
    mov %eax, (%edi)         # First 512GB

    mov $pdpt_base, %edi
    mov $pd_base, %eax
    or $0x3, %eax
    mov %eax, (%edi)         # First 1GB

    # Map 2MB pages for heap region
    mov $pd_base, %edi
    mov $0x83, %eax          # Present + R/W + 2MB
    mov $(0x19969000 >> 21), %ecx  # Number of 2MB pages needed
1:
    mov %eax, (%edi)
    add $0x200000, %eax      # Next 2MB
    add $8, %edi
    loop 1b

    # Enable PAE
    mov %cr4, %eax
    or $0x20, %eax
    mov %eax, %cr4

    # Load CR3
    mov $pml4_base, %eax
    mov %eax, %cr3

    # Enable Long Mode
    mov $0xC0000080, %ecx
    rdmsr
    or $0x100, %eax
    wrmsr

    # Enable paging
    mov %cr0, %eax
    or $0x80000001, %eax
    mov %eax, %cr0

    lgdt (gdt_descriptor_64)
    
    .byte 0xEA
    .long long_mode_start
    .word 0x08

.align 16
.code64
long_mode_start:
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss

    call main

    movw $0x2000, %ax
    movw $0x604, %dx
    outw %ax, %dx
    
    hlt

.section .rodata
.align 16
gdt_64:
    .quad 0
    .quad 0x00AF9A000000FFFF
    .quad 0x00AF92000000FFFF
    
gdt_descriptor_64:
    .word gdt_descriptor_64 - gdt_64 - 1
    .quad gdt_64

.section .bss
.align 4096
pml4_base:
    .skip 4096
pdpt_base:
    .skip 4096
pd_base:
    .skip 4096