#include <stdint.h>

#define PCI_CONFIG_ADDRESS 0xCF8
#define PCI_CONFIG_DATA 0xCFC

#define BUS_NUMBER 0
#define DEVICE_NUMBER 5
#define FUNCTION_NUMBER 0
#define PCI_BAR0_OFFSET 0x10
#define PCI_COMMAND_OFFSET 0x04
#define PCI_VID_OFFSET 0x00
#define PCI_DID_OFFSET 0x02
#define HCIVERSION_OFFSET 0x02

#define MMIO_ADDRESS 0x69420000

volatile uint16_t *vga_buffer = (uint16_t *)0xB8000;

void vga_print(const char *str, uint8_t row, uint8_t col) {
    uint16_t *ptr = vga_buffer + (row * 80 + col);
    while (*str) {
        *ptr++ = (*str++ | 0x0F00);  // White text on black background
    }
}

void vga_print_hex(uint32_t value, uint8_t row, uint8_t col) {
    char buffer[9] = "00000000";
    for (int i = 7; i >= 0; i--) {
        uint8_t nibble = (value & 0xF);
        buffer[i] = nibble < 10 ? ('0' + nibble) : ('A' + nibble - 10);
        value >>= 4;
    }
    vga_print(buffer, row, col);
}

uint32_t pci_read(uint32_t bus, uint32_t device, uint32_t function,
                  uint32_t offset) {
    uint32_t address = (1 << 31) | (bus << 16) | (device << 11) |
                       (function << 8) | (offset & 0xFC);
    asm volatile("outl %0, %1" : : "a"(address), "d"(PCI_CONFIG_ADDRESS));
    uint32_t value;
    asm volatile("inl %1, %0" : "=a"(value) : "d"(PCI_CONFIG_DATA));
    return value;
}

void pci_write(uint32_t bus, uint32_t device, uint32_t function, uint32_t offset,
               uint32_t value) {
    uint32_t address = (1 << 31) | (bus << 16) | (device << 11) |
                       (function << 8) | (offset & 0xFC);
    asm volatile("outl %0, %1" : : "a"(address), "d"(PCI_CONFIG_ADDRESS));
    asm volatile("outl %0, %1" : : "a"(value), "d"(PCI_CONFIG_DATA));
}

int setup_xhci() {
    // Step 1: Enable Bus Master for the xHCI device
    uint32_t cmd =
        pci_read(BUS_NUMBER, DEVICE_NUMBER, FUNCTION_NUMBER, PCI_COMMAND_OFFSET);
    cmd |= (1 << 2);  // Set the Bus Master Enable bit
    pci_write(BUS_NUMBER, DEVICE_NUMBER, FUNCTION_NUMBER, PCI_COMMAND_OFFSET,
              cmd);

    // Step 2: Write the desired MMIO address to BAR0
    pci_write(BUS_NUMBER, DEVICE_NUMBER, FUNCTION_NUMBER, PCI_BAR0_OFFSET,
              MMIO_ADDRESS & ~0xF);

    // Step 3: Verify the BAR0 value
    uint32_t bar0 =
        pci_read(BUS_NUMBER, DEVICE_NUMBER, FUNCTION_NUMBER, PCI_BAR0_OFFSET);
    vga_print("BAR0:", 0, 0);
    vga_print_hex(bar0, 0, 6);

    // Step 4: Read the VID and DID
    uint16_t vid =
        pci_read(BUS_NUMBER, DEVICE_NUMBER, FUNCTION_NUMBER, PCI_VID_OFFSET) &
        0xFFFF;
    uint16_t did =
        (pci_read(BUS_NUMBER, DEVICE_NUMBER, FUNCTION_NUMBER, PCI_DID_OFFSET) >>
         16) &
        0xFFFF;
    vga_print("VID:", 1, 0);
    vga_print_hex(vid, 1, 4);
    vga_print("DID:", 2, 0);
    vga_print_hex(did, 2, 4);

    // Step 5: Read the HCIVERSION register
    volatile uint32_t *mmio_base = (volatile uint32_t *)(MMIO_ADDRESS & ~0xF);
    uint16_t hciversion =
        *((volatile uint16_t *)(mmio_base + HCIVERSION_OFFSET / 2));
    vga_print("HCIVERSION:", 3, 0);
    vga_print_hex(hciversion, 3, 11);

    // Halt the system
    while (1) {
        asm volatile("hlt");
    }

    return 0;
}
