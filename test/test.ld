ENTRY(_start)

SECTIONS {
    . = 1M;  /* Load address */
    
    .text : {
        *(.multiboot)
        *(.text)    /* All .text sections */
    }

    .data : {
        *(.data)    /* All .data sections */
    }

    .bss : {
        *(.bss)     /* All .bss sections */
        *(COMMON)
    }
}
