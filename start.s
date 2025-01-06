.set ALIGN,    1<<0             /* align loaded modules on page boundaries */
.set MEMINFO,  1<<1             /* provide memory map */
.set FLAGS,    ALIGN | MEMINFO  /* this is the Multiboot 'flag' field */
.set MAGIC,    0x1BADB002       /* 'magic number' lets bootloader find the header */
.set CHECKSUM, -(MAGIC + FLAGS) /* checksum of above, to prove we are multiboot */
.set XHCI_ADDR, 0x69420

.set PCI_CONFIG_ADDRESS, 0xCF8
.set PCI_CONFIG_DATA,    0xCFC
.set PCI_BAR_0_OFFSET,   0x10
.set PCI_BAR_1_OFFSET,   0x14

.set PCI_BUS_SHIFT,      16      /* Precomputed shifts */
.set PCI_DEVICE_SHIFT,   11
.set PCI_FUNCTION_SHIFT, 8
.set PCI_BUS_NUMBER,     0x10000 /* 1 shifted left by 16 */
.set PCI_DEVICE_NUMBER,  0x2800 /* 5 shifted left by 11 */
.set PCI_FUNCTION_NUMBER, 0x00 /* 0 shifted left by 8 */

/* Macro to write to PCI register */
.macro write_pci_register reg_offset, value
    /* Compute PCI address in EAX */
    movl 0x80000000, %eax                /* Set the enable bit (bit 31) */
    orl PCI_BUS_NUMBER, %eax             /* Add precomputed bus number */
    orl PCI_DEVICE_NUMBER, %eax          /* Add precomputed device number */
    orl PCI_FUNCTION_NUMBER, %eax        /* Add precomputed function number */
    orl \reg_offset, %eax                 /* Add register offset */
    andl $0xFFFFFFFC, %eax                /* Mask lower two bits (alignment) */
    movw PCI_CONFIG_ADDRESS, %dx
    outl %eax, %dx                        /* Write to PCI CONFIG_ADDRESS */

    /* Write the value to PCI CONFIG_DATA */
    movl \value, %eax
    movw PCI_CONFIG_DATA, %dx
    outl %eax, %dx
.endm


.section .multiboot
.align 4
.global _boot_grub
_boot_grub:
    .long MAGIC
    .long FLAGS
    .long CHECKSUM

# .section .bss
# .align 16
# stack_bottom:
# .skip 16384 # 16 KiB
# stack_top:

.section .text
.global _start
.code32            
_start:
    cli                       # Disable interrupts
    xor %ax, %ax              # Zero AX register
    mov %ax, %ds              # Set data segment
    mov %ax, %es              # Set extra segment
    mov $__stack_top, %esp
	xor %ebp, %ebp              # Cleanup Stack

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
	xor %rbp, %rbp              # Cleanup Stack
    
    # Load data segment selectors for 64-bit mode (not really used, but here for completeness)
    mov $0x10, %rax           # Data segment selector (64-bit)
    mov %rax, %ds
    mov %rax, %es
    mov %rax, %fs
    mov %rax, %gs
    
    
    # Write XHCI_ADDR to BAR0
    write_pci_register PCI_BAR_0_OFFSET, XHCI_ADDR

    # Clear BAR1 (optional, depending on your configuration)
    # write_pci_register PCI_BAR_1_OFFSET, 0x0

    # Verify MMIO mapping by writing and reading back
    movl $XHCI_ADDR, %eax         # Load MMIO base address into %rax
    movb $0x7D, (%rax)            # Write a test value to MMIO
    movb (%rax), %al              # Read back the value
    cmpb 0x7D, %al                # Compare to ensure mapping succeeded
    je success

    # If mapping fails, indicate error
    movq 0xB8000, %rax           # VGA text mode address
    movw $0x4F58, (%rax)         # Red 'X'
    # hlt

success:
    # extern main

    # Debugging
    mov main, %rax            # Load the address of `main` into RAX
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
