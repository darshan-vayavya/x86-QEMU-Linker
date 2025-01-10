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

.code32
.section .data
test_value: .long 0x12345678      # Known 32-bit value (4 bytes)

.section .text
.globl _start
_start:
    cli                          # Disable interrupts

    movl $test_value, %eax       # Load the address of the test value
    movl (%eax), %ebx            # Load the value into EBX

    # Extract each byte for verification
    movb %bl, %cl                # Least significant byte
    shr $8, %ebx                 # Shift EBX right by 8 bits
    movb %bl, %ch                # Next byte
    shr $8, %ebx
    movb %bl, %dh                # Next byte
    shr $8, %ebx
    movb %bl, %dl                # Most significant byte

    hlt                          # Halt the CPU
