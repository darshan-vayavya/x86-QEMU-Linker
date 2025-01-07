.set ALIGN,    1<<0             # align loaded modules on page boundaries
.set MEMINFO,  1<<1             # provide memory map
.set FLAGS,    ALIGN | MEMINFO  # this is the Multiboot 'flag' field
.set MAGIC,    0x1BADB002       # 'magic number' lets bootloader find the header
.set CHECKSUM, -(MAGIC + FLAGS) # checksum of above, to prove we are multiboot

.align 16
.set XHCI_ADDR, 0x00F0C0

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

_xHCI_mmio_read:
     # Step 1: Write to PCI Configuration Address Register to access BAR0
    movl $0x80001010, %eax      # 0x80000000 | (Bus=0 << 16) | (Device=1 << 11) | (Function=5 << 8) | BAR0 offset (0x10)
    movw $0xCF8, %dx            # PCI configuration address register
    outl %eax, %dx              # Write full 32 bits to PCI_CONFIG_ADDRESS

    # Step 2: Read the current BAR0 value
    movw $0xCFC, %dx            # PCI configuration data register
    inl %dx, %eax               # Read 32-bit data from PCI_CONFIG_DATA into %eax

_xHCI_HCSPARAMS1_read:
    add $0x04, %eax             # HCSPARAMS1 is at BASE+04H
    mov (%eax), %ebx           # Read HCSPARAMS1 register value

_xHCI_mmio_map:
    # Step 3: Write the new MMIO base address (0xED69420) to BAR0
    movl $XHCI_ADDR, %eax       # New MMIO base address (aligned to 16 bytes)
    movw $0xCF8, %dx            # PCI configuration address register
    outl %eax, %dx              # Write BAR0 address to PCI_CONFIG_ADDRESS

    movw $0xCFC, %dx            # PCI configuration data register
    outl %eax, %dx              # Write the new MMIO base address to BAR0

    # Step 4: Verify the new MMIO base address
    movl $0x80001010, %eax      # PCI Configuration Address for BAR0
    movw $0xCF8, %dx
    outl %eax, %dx              # Write to PCI Configuration Address Register

    movw $0xCFC, %dx            # PCI Configuration Data Register
    inl %dx, %eax               # Read back BAR0 value
    cmpl $XHCI_ADDR, %eax       # Check if it matches 0xED69420
    je start_main               # If equal, remapping succeeded

failure:
    # hlt                         # Halt if remapping failed
    
# Call C main function
start_main:
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
