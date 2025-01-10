.set ALIGN,    1<<0             # align loaded modules on page boundaries
.set MEMINFO,  1<<1             # provide memory map
.set FLAGS,    0x00 # this is the Multiboot 'flag' field
.set MAGIC,    0x1BADB002       # 'magic number' lets bootloader find the header
.set CHECKSUM, -(MAGIC + FLAGS) # checksum of above, to prove we are multiboot

.set CONFIG_ADDRESS, 0x0CF8
.set CONFIG_DATA, 0x0CFC

# Multiboot headers

.section .multiboot
.align 4
.global _boot_grub
_boot_grub:
    .long MAGIC
    .long FLAGS
    .long CHECKSUM

# Start Section
.section .text
.global _start

_start:
    # Step 1: Write the PCI device address (0x80002810) to the address register
    movl $0x80002810, %eax     # Bus 0, Device 5, Function 0, Offset 0x10 (BAR0)
    movw $CONFIG_ADDRESS, %dx
    outl %eax, %dx             # Write to CONFIG_ADDRESS

    # Step 2: Write 0xFFFFFFFF to the PCI Data register (to read BAR0 value)
    movl $0xFFFFFFFF, %eax
    movw $CONFIG_DATA, %dx
    outl %eax, %dx            # Write 0xFFFFFFFF to CONFIG_DATA

    # Step 3: Read back the BAR0 value from the PCI Data register
    movl $0x80002810, %eax     # Bus 0, Device 5, Function 0, Offset 0x10 (BAR0)
    movw $CONFIG_ADDRESS, %dx
    outl %eax, %dx             # Write to CONFIG_ADDRESS
    movw $CONFIG_DATA, %dx
    inl %dx, %eax              # Read from CONFIG_DATA (BAR0)
    # andl $0xFFFFFFF0, %eax     # Mask last 4 bits to get MMIO size
    movl %eax, %ebx            # Save MMIO size in EBX

    # Step 4: Calculate MMIO base address
    movl $0xFEC00000, %ecx     # Example MMIO base address (ensure it's free)
    movl $0x80002810, %eax     # Bus 0, Device 5, Function 0, Offset 0x10 (BAR0)
    movw $CONFIG_ADDRESS, %dx
    outl %eax, %dx             # Write to CONFIG_ADDRESS
    movl %ecx, %eax            # Load MMIO base address into EAX
    movw $CONFIG_DATA, %dx
    outl %eax, %dx            # Assign MMIO base address to BAR0

    # Step 5: Verify the MMIO address
    movl $0x80002810, %eax
    movw $CONFIG_ADDRESS, %dx
    outl %eax, %dx             # Write to CONFIG_ADDRESS
    movw $CONFIG_DATA, %dx
    inl %dx, %eax              # Read BAR0 value
    andl $0xFFFFFFF0, %eax     # Mask last 4 bits
    cmpl %ecx, %eax            # Compare with assigned MMIO address
    jne error                  # Jump to error if mismatch

    # Step 6: Access MMIO registers
    movl %ecx, %esi            # Load MMIO base address into ESI
    addl $0x2, %esi            # Offset for HCIVERSION
    movw (%esi), %ax           # Read 16-bit HCIVERSION

    # Successful read, halt the CPU
    hlt

error:
    movl $0xdeadbeef, %eax     # Error code for debugging
    hlt
