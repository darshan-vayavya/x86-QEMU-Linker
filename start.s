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

.section .text
.global _start
.code32
_start:
    cli                     # Disable interrupts

    # Setup stack
    mov $__stack_top, %esp
    mov %esp, %ebp
    
    # Disable cache
    mov %cr0, %eax
    or $0x60000000, %eax   # Set CD and NW bits
    mov %eax, %cr0
    wbinvd                 # Flush cache

    # Initialize FPU
    fninit

    # Display welcome message
    call display_boot

    # Jump to main
    call main

_end:
    # Display end message
    call display_end

    # Close QEMU
    movw $0x2000, %ax
    movw $0x604, %dx
    outw %ax, %dx
    
    # Safety barrier
    hlt

.section .rodata
.align 16
gdt:
    .quad 0
    .quad 0x00CF9A000000FFFF  # 32-bit code
    .quad 0x00CF92000000FFFF  # 32-bit data
    
gdt_descriptor:
    .word gdt_descriptor - gdt - 1
    .long gdt
