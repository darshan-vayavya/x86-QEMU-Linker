; Assembly code for x86 Machine start code.
; Author: Darshan(@thisisthedarshan) <darshanp@vayavyalabs.com>
; This assembly code is used to boot the bare-metal QEMU system to enable us to
; run custom C code.
; The C code is generated using GCC's x86 build tools. The Makefile is included
; to build the binaries that can be run on QEMU's x86 system
; The project assumes a RAM space of 1GB


    .global _start

    ; Define constants 
    %define GDT_ENTRY_COUNT 3
    %define GDT_BASE 0x1000            /* GDT base address */
    %define GDT_LIMIT 0xFFFF          /* GDT limit (64KB max for GDT) */
    %define KERNEL_STACK_SIZE 0x2000  /* 8KB Stack size */
    %define KERNEL_HEAP_SIZE 0x100000 /* 1MB Heap size */
    %define RAM_SIZE 0x40000000       /* 1GB of RAM */

    ; 64-bit entry point 
    .section .text
_start:
    ; Initialize GDT 
    call init_gdt

    ; Load GDT 
    lgdt [gdt_descriptor]

    ; Switch to long mode 
    call switch_to_long_mode

    ; Initialize stack and heap 
    call init_stack

    ; Jump to main function 
    call main

    ; Infinite loop to keep the system running 
    hang:
        jmp hang

    ; GDT setup function 
init_gdt:
    ; GDT descriptor setup 
    lidt [gdt_descriptor]   ; Load GDT descriptor 

    ; GDT Table 
    ; GDT entry 0: Null descriptor (unused)
    dq 0x0000000000000000
    ; GDT entry 1: Code segment (kernel code, ring 0, 64-bit)
    dq 0x00CF9A000000FFFF
    ; GDT entry 2: Data segment (kernel data, ring 0, 64-bit)
    dq 0x00CF92000000FFFF

    ; GDT descriptor (limit, base address) 
gdt_descriptor:
    dw GDT_LIMIT & 0xFFFF       /* Limit low */
    dw (GDT_BASE & 0xFFFF)      /* Base low */
    db (GDT_BASE >> 16) & 0xFF  /* Base middle byte */
    db 0x00                     /* Access byte (ignore for now) */
    db 0x00                     /* Granularity byte (ignore for now) */
    db (GDT_BASE >> 24) & 0xFF  /* Base high byte */

    ret

; Switch to long mode (64-bit mode) 
switch_to_long_mode:
    ; Set 64-bit mode flag in EFLAGS (EFER.LME = 1)
    mov eax, cr0
    or eax, 0x80000000     ; Set the long mode flag (bit 31) in CR0
    mov cr0, eax

    ; Enable paging and 64-bit mode
    mov eax, 0xC0000080   ; MSR for EFER
    rdmsr
    or eax, 0x00000100    ; Enable long mode (EFER.LME = 1)
    wrmsr

    ; Switch to 64-bit mode (requires a jump to a 64-bit address)
    jmp 0x08:long_mode     ; Far jump to 64-bit code segment

long_mode:
    ; Now in 64-bit mode (long mode), continue initialization
    ret

; Initialize stack for the kernel 
init_stack:
    ; Setup stack pointer for the kernel
    mov rsp, 0x2000        ; Set the stack pointer to the top of the kernel stack (8KB)

    ret
