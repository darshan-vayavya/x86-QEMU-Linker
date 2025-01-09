.set ALIGN,    1<<0             # align loaded modules on page boundaries
.set MEMINFO,  1<<1             # provide memory map
.set FLAGS,    ALIGN | MEMINFO  # this is the Multiboot 'flag' field
.set MAGIC,    0x1BADB002       # 'magic number' lets bootloader find the header
.set CHECKSUM, -(MAGIC + FLAGS) # checksum of above, to prove we are multiboot

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

# Macro to write a value at an address in PCI
.macro write_pci addr, value
    movl \addr, %eax          # Load the PCI address (register) into %eax
    movw $0xCF8, %dx          # PCI configuration address register
    outl %eax, %dx            # Write the address to the PCI configuration register

    movl \value, %eax         # Load the value to write into %eax
    movw $0xCFC, %dx          # PCI configuration data register
    outl %eax, %dx            # Write the value to the PCI configuration data register
    mfence                    # Memory fence to ensure the write operation is completed
.endm


.section .multiboot
.align 4
.global _boot_grub
_boot_grub:
    .long MAGIC
    .long FLAGS
    .long CHECKSUM

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
    # mov %cr0, %eax
    # or $0x1, %eax              # Set the PE bit
    # mov %eax, %cr0

    # mov $0x10, %ax             # Load data selector into segments
    # mov %ax, %ds
    # mov %ax, %es
    # mov %ax, %fs
    # mov %ax, %gs
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

    # Disable caching by clearing the CD and NW bits in CR0
    # movl %cr0, %eax            # Load CR0 register value into %eax
    # btcl $30, %eax             # Set the CD (Cache Disable) bit (bit 30)
    # btcl $29, %eax             # Set the NW (No Write-Through) bit (bit 29)
    # movl %eax, %cr0            # Store the modified value back into CR0

    # Invalidate the cache after disabling caching
    invd                      # Invalidate the internal cache

_xHCI_setup:
    read_pci $xHCI_BAR0_ADDR
    and $0xFFFFFFF0, %eax     # Mask - from osdev
    # movl %eax, %ebx           # Copy so that we keep original address to reuse
    # add $0x40, %ebx         # From xHCI QEMU - constant
    # mov (%ebx), %ecx        # Reset xHCI controller
    # movl $0x02, (%ebx)      # Reset the controller - set bit 1 to 1 for reset
    # movl (%ebx), %ecx       # Read the value back into %ecx

    # add $0x2, %ebx          # Add offset of +2H to read HCIVERSION
    movl (%eax), %ebx            # Read 64-bit value from MMIO address into rbx        # Read its contents into eax register

    write_pci $xHCI_BAR0_ADDR, $0xFFFFFFFF
    read_pci $xHCI_BAR0_ADDR

_xHCI_enable_bus_master:
    read_pci $xHCI_CMDR_ADDR
    orl %eax, 0x02
    movw $0xCFC, %dx               # PCI configuration data register
    outl %eax, %dx                 # Write the new MMIO base address to BAR0
    mfence

_xHCI_mmio_mse:
    read_pci $xHCI_CMDR_ADDR    # Value Obtained = 0x100107
/*
    1b36:000d  -   PCI xhci usb host adapter
 */
_xHCI_VID:
    read_pci $xHCI_VID_ADDR     # Value Obtained = 0xd1b36 - 1b36
_xHCI_DID:
    read_pci $xHCI_DID_ADDR     # Value Obtained = 0x107000d - 000d
_xHCI_PCI_BUS_HEADER:
    read_pci $xHCI_HEAD_ADDR    # Value Obtained = 0x40000  00
_xHCI_PCI_BAR1:
    read_pci $xHCI_BAR1_ADDR    # Value Obtained = 0x0

_xHCI_mmio_read:
    # Step 1: Write to PCI Configuration Address Register to access BAR0
    read_pci $xHCI_BAR0_ADDR
    # and $0xFFFFFFF0, %eax       # Mask lower 4 bits to get MMIO base address
    test %eax, %eax             # Check if BAR0 is valid
    jz failure                  # Handle error if MMIO base is invalid

_xHCI_HCIVERSION_read:
    add $0x02, %eax             # HCIVERSION is at BASE+02H
    mov %eax, %ebx
    mov (%ebx), %eax            # Read HCIVERSION register value

_xHCI_mmio_map:
    # Write new MMIO address to BAR0
    movl $xHCI_BAR0_ADDR, %eax     # PCI BAR0 address register (Base Address Register 0)
    movw $0xCF8, %dx               # PCI configuration address register
    outl %eax, %dx                 # Write to select PCI configuration address register
    mfence                   # Ensure the write completes

    # Write the custom MMIO base address to BAR0
    movl $__mmio_region_start, %eax          # Load the custom MMIO base address into EAX
    movw $0xCFC, %dx               # PCI configuration data register
    outl %eax, %dx                 # Write the new MMIO base address to BAR0
    mfence 
    
    # Set MSE bit:
    movl $xHCI_CMDR_ADDR, %eax       # Address for PCI Command Register
    movw $0xCF8, %dx
    outl %eax, %dx
    mfence                       # Ensure all memory operations are completed

    movw $0xCFC, %dx
    inl %dx, %eax                # Read current Command Register value
    orl $0x2, %eax               # Set bit 1 (MSE)
    outl %eax, %dx               # Write back to Command Register
    mfence                       # Ensure all memory operations are completed

    invd                         # Invalidate internal CPU caches
    
    # movq %cr3, %rax     # Move the value of CR3 into RAX (64-bit register)
    # movq %rax, %cr3     # Move the value from RAX back into CR3


    # Read BAR0
    read_pci $xHCI_BAR0_ADDR

    cmpl $__mmio_region_start, %eax       # Check if it matches 0xED69420
    je start_main               # If equal, remapping succeeded

failure:
    hlt                         # Halt if remapping failed


.code64
_code64:
    mov $__stack_top, %rsp     # Set up 64-bit stack
    xor %rbp, %rbp

# Call C main function
start_main:
    read_pci $xHCI_BAR0_ADDR
    andl $0xFFFFFFF0, %eax
    add $0x02, %eax             # HCSPARAMS1 is at BASE+04H
    mov %eax, %edx
    movw (%edx), %dx            # Read HCSPARAMS1 register value
    call main
    hlt

.section .rodata
.align 4096

gdt_32:
    .quad 0x0000000000000000   # Null descriptor
    .quad 0x00AF9A000000FFFF  # Code segment (32-bit)
    .quad 0x00AF92000000FFFF  # Data segment (32-bit)

gdt_descriptor_32:
    .word (gdt_end_32 - gdt_32 - 1)
    .quad gdt_32
gdt_end_32:

gdt_64:
    .quad 0x0000000000000000   # Null descriptor
    .quad 0x00A09A0000000000   # 64-bit code segment
    .quad 0x00A0920000000000   # 64-bit data segment

gdt_descriptor_64:
    .word (gdt_end_64 - gdt_64 - 1)
    .quad gdt_64
gdt_end_64:
