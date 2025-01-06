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
    mov $__stack_top, %rsp     # Set up 64-bit stack
    xor %rbp, %rbp

    mov $XHCI_ADDR, %eax        # Load XHCI_ADDR (0xED69420)

    # lgdt gdt_descriptor_64        # Load the GDT

    # PCI memory mapping for xHCI device at PCI address 01.5
    # Set up PCI Configuration Address to access the PCI device at 01.5
    mov $0x80001000, %rax      # PCI device address for 01.5 (0x80001000)
    movw $0xCF8, %dx            # PCI configuration address register
    out %eax, %dx              # Write full 32 bits to PCI_CONFIG_ADDRESS

    movw $0xCFC, %dx            # PCI configuration data register
    inl %dx, %eax               # Read 32-bit data from PCI_CONFIG_DATA into %eax
    movl %eax, %eax             # (Optional) Ensure %eax is treated as 32 bits
    
    # Assuming BAR0 is memory-mapped and we want to set XHCI_ADDR to the value
    # of BAR0 (which is where we can access the xHCI device MMIO space)
    mov $XHCI_ADDR, %rbx
    mov %rax, (%rbx)        # Store the value into XHCI_ADDR

    # Example: Write data to the xHCI MMIO address (0xED69420)
    mov $0x1000, %rax          # Some data to write
    mov $XHCI_ADDR, %rcx        # Load XHCI_ADDR (0xED69420)
    mov %rax, (%rcx)           # Write data to the xHCI MMIO address

    # Read the value back from xHCI MMIO to verify (same address)
    mov $XHCI_ADDR, %rcx        # Load XHCI_ADDR again
    mov (%rcx), %rax           # Read the value from the xHCI MMIO address
    cmp $0x1000, %rax          # Compare with expected value

    ljmp $0x08, $start_main
    
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
