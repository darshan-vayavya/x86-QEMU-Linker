/* Linker Script to build binaries for x86 device 
 * Author: Darshan(@thisisthedarshan) <darshanp@vayavyalabs.com>
 * This linker script is used with the start.s assembly file to build (bare-metal)
 * binaries to run on a x86 QEMU device. The project is designed with an idea that
 * the usage is on a system with 1GB RAM space. The included Makefile should build
 * the assembly file as well as your .c files, link them together and generate binary
 * that can be run on a bare-metal system.
 */

HEAP_START = 0x1D369000;
HEAP_SIZE = 0x19969000; /* ~430 MB */
STACK_SIZE = 65536; /* ~ 64 KiB */

ENTRY(_start)    /* Entry point for the kernel */

SECTIONS {
    /* Define the start of the memory layout */
    /* .text section holds the kernel code */
    . = 2M;  /* Set the entry point address */
    .text : ALIGN(4K) {
        *(.multiboot)  /* Include the Multiboot header */
        *(.text)       /* Collect all .text sections from object files */
    }

    /* .rodata section holds read-only data like constants */
    .rodata : ALIGN(4K) {
        *(.rodata)    /* Collect all .rodata sections from object files */
    }

    /* .data section holds initialized global and static variables */
    .data : ALIGN(4K) {
        *(.data)      /* Collect all .data sections from object files */
    }

    /* .bss section holds uninitialized global and static variables */
    .bss : ALIGN(4K) {
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
        . = . + STACK_SIZE;       /* Allocate 64KiB for the stack (adjustable) */
        __stack_top = .;      /* Mark the end of the stack */
    }

    /* Define the heap section at a fixed address - since we are doing bare-metal*/
    . = HEAP_START;
    .heap : ALIGN(4K) {
        __heap_start = .;    /* Mark the start of the heap at the current location */
        . = . + HEAP_SIZE;   /* Allocate 429.298 MB for the heap (adjustable) */
        __heap_end = .;      /* Mark the end of the heap at the current location */
    }

    /* Data relocation and alignment for other sections */
    _end = .;        /* Define the end of the program's memory region */
}
