#include <stdint.h>

// Define MMIO base address (hardcoded for this example)
#define XHCI_BASE_ADDR 0x0ED69420

// Define offsets for HCSPARAMS1 and HCCPARAMS1 registers
#define HCSPARAMS1_OFFSET 0x04
#define HCCPARAMS1_OFFSET 0x10

// Function to read a 32-bit value from a memory-mapped register
static inline uint32_t mmio_read32(uintptr_t addr) {
    return *(volatile uint32_t *)addr;
}

int main() {
    // Pointers to the registers
    volatile uint32_t hcsp1_value = 0, hccp1_value = 0;

    // Read HCSPARAMS1 register
    hcsp1_value = mmio_read32(XHCI_BASE_ADDR + HCSPARAMS1_OFFSET);

    // Read HCCPARAMS1 register
    hccp1_value = mmio_read32(XHCI_BASE_ADDR + HCCPARAMS1_OFFSET);

    // Variables can be checked using GDB or printed if serial output is
    // available
    hcsp1_value = hcsp1_value;
    hccp1_value = hccp1_value;
    while (1);  // Infinite loop to keep the program running
    return 0;
}
