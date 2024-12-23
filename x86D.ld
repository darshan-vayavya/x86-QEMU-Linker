/* Linker Script to build binaries for x86 device 
 * Author: Darshan(@thisisthedarshan) <darshanp@vayavyalabs.com>
 * This linker script is used with the start.s assembly file to build (bare-metal)
 * binaries to run on a x86 QEMU device. The project is designed with an idea that
 * the usage is on a system with 1GB RAM space. The included Makefile should build
 * the assembly file as well as your .c files, link them together and generate binary
 * that can be run on a bare-metal system.
 */
OUTPUT_FORMAT("elf64-x86-64")

ENTRY(_start)    /* Entry point for the kernel */

SECTIONS {
    /* Define the start of the memory layout */
    . = 0x100000;  /* Start the program at 1MB (0x100000) */

    /* .text section holds the kernel code */
    .text : {
        *(.text)       /* Collect all .text sections from object files */
        start.o(.text) /* Include start.o's .text section */
    }

    /* .data section holds initialized global and static variables */
    .data : {
        *(.data)      /* Collect all .data sections from object files */
    }

    /* .rodata section holds read-only data like constants */
    .rodata : {
        *(.rodata)    /* Collect all .rodata sections from object files */
    }

    /* .bss section holds uninitialized global and static variables */
    .bss : {
        *(.bss)       /* Collect all .bss sections */
        *(COMMON)     /* Include uninitialized global variables */
        __bss_start = .;  /* Mark the start of the bss segment */
        __bss_end = .;    /* Mark the end of the bss segment */
    }

    /* .sig section holds the boot signature (0xAA55) */
    .sig : AT(ADDR(.text) + 512 - 2) {
        SHORT(0xAA55);   /* 0xAA55 signature, required by BIOS */
    }

    /* Discard unnecessary sections */
    /DISCARD/ : {
        *(.eh_frame)   /* Discard exception handling frames */
    }

    /* Stack section */
    .stack (NOLOAD) : {
        __stack_bottom = .;  /* Mark the start of the stack */
        . = . + 0x2000;       /* Allocate 8KB for the stack (adjustable) */
        __stack_top = .;      /* Mark the end of the stack */
    }

    /* Define the heap section (after stack) */
    .heap : {
        __heap_start = .;    /* Mark the start of the heap */
        . = . + 0x100000;     /* Allocate 1MB for the heap (adjustable) */
        __heap_end = .;      /* Mark the end of the heap */
    }

    /* Define available free RAM section */
    .free_ram : {
        __free_ram_start = .;  /* Mark the start of free memory after the heap */
        . = 0x40000000;         /* Mark the end of memory at 1GB (0x40000000) */
        __free_ram_end = .;    /* Mark the end of free memory */
    }

    /* Data relocation and alignment for other sections */
    . = ALIGN(8);    /* Align to 8-byte boundary */
    _end = .;        /* Define the end of the program's memory region */
}
