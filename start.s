.set ALIGN,    1<<0             # align loaded modules on page boundaries
.set MEMINFO,  1<<1             # provide memory map
.set FLAGS,    ALIGN | MEMINFO  # this is the Multiboot 'flag' field
.set MAGIC,    0x1BADB002       # 'magic number' lets bootloader find the header
.set CHECKSUM, -(MAGIC + FLAGS) # checksum of above, to prove we are multiboot

# xHCI Address
.set XHCI_ADDR, 0xED69420 & ~0xF

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
.set PCI_CACHE_LINE_SIZE, 0x0C  # Cache Line Size (8 bits)
.set PCI_LATENCY_TIMER, 0x0D    # Latency Timer (8 bits)
.set PCI_HEADER_TYPE, 0x0E      # Header Type (8 bits)
.set PCI_BIST, 0x0F             # Built-in Self-Test (8 bits)

.set PCI_BAR_0_OFFSET, 0x10     # Base Address Register 0 (32 bits or 64 bits)
.set PCI_BAR_1_OFFSET, 0x14     # Base Address Register 1 (32 bits or 64 bits)
.set PCI_BAR_2_OFFSET, 0x18     # Base Address Register 2 (32 bits or 64 bits)
.set PCI_BAR_3_OFFSET, 0x1C     # Base Address Register 3 (32 bits or 64 bits)
.set PCI_BAR_4_OFFSET, 0x20     # Base Address Register 4 (32 bits or 64 bits)
.set PCI_BAR_5_OFFSET, 0x24     # Base Address Register 5 (32 bits or 64 bits)

.set PCI_CARDBUS_CIS_OFFSET, 0x28 # CardBus CIS Pointer (32 bits)
.set PCI_SUBSYSTEM_VENDOR_ID, 0x2C # Subsystem Vendor ID (16 bits)
.set PCI_SUBSYSTEM_ID, 0x2E     # Subsystem ID (16 bits)
.set PCI_EXPANSION_ROM_ADDR, 0x30 # Expansion ROM Base Address (32 bits)
.set PCI_CAP_PTR, 0x34          # Capabilities Pointer (8 bits)
.set PCI_RESERVED_1, 0x35       # Reserved (24 bits)
.set PCI_INT_LINE, 0x3C         # Interrupt Line (8 bits)
.set PCI_INT_PIN, 0x3D          # Interrupt Pin (8 bits)
.set PCI_MIN_GRANT, 0x3E        # Minimum Grant (8 bits)
.set PCI_MAX_LATENCY, 0x3F      # Maximum Latency (8 bits)

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

    lgdt gdt_descriptor_64        # Load the GDT

    # Enable protected mode
    mov %cr0, %eax
    or $0x1, %eax              # Set the PE bit
    mov %eax, %cr0

    mov $0x10, %ax             # Load data selector into segments
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss

    # Enable Long Mode
    movl $0xC0000080, %ecx     # Load EFER MSR
    rdmsr
    orl $0x00000100, %eax      # Set LME (Long Mode Enable)
    wrmsr

    mov %cr4, %eax
    or $0x20, %eax             # Enable PAE (Physical Address Extension)
    mov %eax, %cr4

.code64
_code_64:
    mov $__stack_top, %rsp     # Set up 64-bit stack
    xor %rbp, %rbp

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
    read_pci $xHCI_HEAD_ADDR    # Value Obtained = 0x40000
_xHCI_PCI_BAR1:
    read_pci $xHCI_BAR1_ADDR    # Value Obtained = 0x0

_xHCI_mmio_read:
    # Step 1: Write to PCI Configuration Address Register to access BAR0
    read_pci $xHCI_BAR0_ADDR
    and $0xFFFFFFF0, %eax       # Mask lower 4 bits to get MMIO base address
    test %eax, %eax             # Check if BAR0 is valid
    jz failure                  # Handle error if MMIO base is invalid

_xHCI_HCSPARAMS1_read:
    add $0x02, %eax             # HCSPARAMS1 is at BASE+04H
    mov %eax, %ebx
    mov (%ebx), %eax            # Read HCSPARAMS1 register value

_xHCI_mmio_map:
    # Write new MMIO address to BAR0
    movl $xHCI_BAR0_ADDR, %eax     # PCI BAR0 address register (Base Address Register 0)
    movw $0xCF8, %dx               # PCI configuration address register
    outl %eax, %dx                 # Write to select PCI configuration address register
    mfence                   # Ensure the write completes

    # Write the custom MMIO base address to BAR0
    movl $XHCI_ADDR, %eax          # Load the custom MMIO base address into EAX
    movw $0xCFC, %dx               # PCI configuration data register
    outl %eax, %dx                 # Write the new MMIO base address to BAR0
    
    
    # Read BAR0
    read_pci $xHCI_BAR0_ADDR

    cmpl $XHCI_ADDR, %eax       # Check if it matches 0xED69420
    je start_main               # If equal, remapping succeeded

failure:
    # hlt                         # Halt if remapping failed
    
# Call C main function
start_main:
    read_pci $xHCI_BAR0_ADDR
    add $0x02, %eax             # HCSPARAMS1 is at BASE+04H
    mov %eax, %ebx
    mov (%ebx), %eax            # Read HCSPARAMS1 register value
    call main
    hlt

.section .data
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
