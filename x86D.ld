/* Linker Script to build binaries for x86 device 
 * Author: Darshan(@thisisthedarshan) <darshanp@vayavyalabs.com>
 * This linker script is used with the start.s assembly file to build (bare-metal)
 * binaries to run on a x86 QEMU device. The project is designed with an idea that
 * the usage is on a system with 1GB RAM space. The included Makefile should build
 * the assembly file as well as your .c files, link them together and generate binary
 * that can be run on a bare-metal system.
 */

ENTRY(_start)    /* Entry point for the kernel */

SECTIONS {
    /* Define the start of the memory layout */
    /* .text section holds the kernel code */
    . = 2M;  /* Set the entry point address */
    .text BLOCK(4K) : ALIGN(4K) {
        *(.multiboot)  /* Include the Multiboot header */
        *(.text)       /* Collect all .text sections from object files */
    }

    /* .rodata section holds read-only data like constants */
    .rodata BLOCK(4K) : ALIGN(4K) {
        *(.rodata)    /* Collect all .rodata sections from object files */
    }

    /* .data section holds initialized global and static variables */
    .data BLOCK(4K) : ALIGN(4K) {
        *(.data)      /* Collect all .data sections from object files */
    }

    /* .bss section holds uninitialized global and static variables */
    .bss BLOCK(4K) : ALIGN(4K) {
        __bss_start = .;  /* Mark the start of the bss segment */
        *(.bss)       /* Collect all .bss sections */
        *(COMMON)     /* Include uninitialized global variables */
        __bss_end = .;    /* Mark the end of the bss segment */
    }

    /* Discard unnecessary sections */
    /DISCARD/ : {
        *(.eh_frame)   /* Discard exception handling frames */
    }

    /* Stack section */
    .stack (NOLOAD) :  ALIGN(16)  {
        __stack_bottom = .;  /* Mark the start of the stack */
        . = . + 16384;       /* Allocate 16KiB for the stack (adjustable) */
        __stack_top = .;      /* Mark the end of the stack */
    }

    /* Define the heap section (after stack) */
    .heap : ALIGN(16)  {
        __heap_start = .;    /* Mark the start of the heap */
        . = . + 0x80000;     /* Allocate 0.5MB for the heap (adjustable) */
        __heap_end = .;      /* Mark the end of the heap */
    }
    /* Data relocation and alignment for other sections */
    _end = .;        /* Define the end of the program's memory region */
}
