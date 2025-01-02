.set ALIGN,    1<<0             /* align loaded modules on page boundaries */
.set MEMINFO,  1<<1             /* provide memory map */
.set FLAGS,    ALIGN | MEMINFO  /* this is the Multiboot 'flag' field */
.set MAGIC,    0x1BADB002       /* 'magic number' lets bootloader find the header */
.set CHECKSUM, -(MAGIC + FLAGS) /* checksum of above, to prove we are multiboot */
.set XHCI_ADDR, 0x07690

.section .multiboot
.align 4
.global _boot_grub
_boot_grub:
    .long MAGIC
    .long FLAGS
    .long CHECKSUM

.section .bss
.align 16
stack_bottom:
.skip 16384 # 16 KiB
stack_top:

.section .text
.global _start
.code32            
_start:
    cli                       # Disable interrupts
    xor %ax, %ax              # Zero AX register
    mov %ax, %ds              # Set data segment
    mov %ax, %es              # Set extra segment
    # mov $0x7000, %ax        # Load 0x7000 into AX
    # mov %ax, %ss              # Move the value in AX to the stack segment

    lgdt gdt_descriptor       # Load GDT
    mov %cr0, %eax            # Move CR0 into EAX
    or $0x1, %eax             # Set the PE bit (bit 0) for protected mode
    mov %eax, %cr0            # Write EAX back to CR0

    mov $0x10, %ax            # Data segment selector
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss

    # Enable long mode without enabling paging
    movl $0xC0000080, %ecx    # Load EFER MSR index
    rdmsr                     # Read EFER
    orl $0x00000100, %eax     # Set LME (long mode enable) bit
    wrmsr                     # Write EFER

    mov %cr4, %eax            # Move CR4 into EAX
    or $0x20, %eax            # Set PAE bit (Physical Address Extension)
    mov %eax, %cr4            # Write EAX back to CR4

    ljmp $0x08, $long_mode_start  # Far jump to 64-bit long mode


.code64                       # 64-bit long mode
.align 4
long_mode_start:
    mov $__stack_top, %rsp    # Set the stack pointer to the top of the 16KB stack (64-bit mode)
    
    # Load data segment selectors for 64-bit mode (not really used, but here for completeness)
    mov $0x10, %rax           # Data segment selector (64-bit)
    mov %rax, %ds
    mov %rax, %es
    mov %rax, %fs
    mov %rax, %gs
    
    # Map xHCI Base Address to XHCI_ADDR (Updated to use 01:5 bus address)
    movl $0x8001A010, %eax     # Update with the 01:5 bus address -  0x80000000 | (1 << 16) | (5 << 11) | (0 << 8) | 0x10
    mov $0xCF8, %dx            # Load CONFIG_ADDRESS port into DX
    outl %eax, %dx             # Write to CONFIG_ADDRESS port

    movl $XHCI_ADDR, %eax      # The new MMIO base address
    mov $0xCFC, %dx            # Load CONFIG_DATA port into DX
    outl %eax, %dx             # Write the MMIO base address to CONFIG_DATA port

    # Debugging
    mov $main, %rax           # Load the address of `main` into RAX
    mov %rax, %rbx            # Copy it to RBX for inspection

    # Jump to main
    call main

    # Infinite loop (hang)
hang:
    jmp hang

.section .data
gdt:
    .quad 0x0000000000000000  # Null descriptor
    .quad 0x00AF9A000000FFFF  # Code segment (32-bit)
    .quad 0x00AF92000000FFFF  # Data segment (32-bit)

gdt_descriptor:
    .word (gdt_end - gdt - 1) # GDT size (limit)
    .long gdt                 # GDT base address
gdt_end:
