# Technical Documentation: Bootstrapping a Bare-Metal x86 System with 1GB RAM

This document explains the process of bootstrapping a **bare-metal x86 system** with **1GB of RAM**. It details the necessary setup, including the **linker script**, **assembly file**, **transition to long mode**, **memory layout**, and the role of **GDT** and **paging**. The final goal is to create a system that runs on an **x86 QEMU environment** using **GCC** for compilation.

## 1. Overview of the System Architecture

The system will run in ~~**64-bit long mode** (as opposed to 16-bit real mode or 32-bit protected mode)~~ **32-bit protected mode** with a **flat memory model**. The ~~**long mode** allows the processor to address a large memory space in a simplified and linear fashion~~ This mode is ideal for modern bare-metal systems as it simplifies memory management and allows the system to use the full capabilities of the x86-64 architecture.

The system will use **1GB of RAM**, and this RAM will be allocated across different regions for the **kernel code**, **data**, **heap**, **stack**, and **free memory**. The **memory-mapped I/O** space (for peripherals like xHCI) will also be handled separately.

## 2. **Linker Script and Memory Layout**

The **linker script** is essential for defining how the compiled code should be laid out in memory. It ensures that sections like `.text`, `.data`, `.bss`, the **stack**, and **heap** are placed at the right locations. Here's the key breakdown of the memory layout:

- **Program Start (0x200000):** The program begins at `0x200000` (2MB) to allow for any BIOS or bootloader requirements.
- **.text Section:** This section contains the executable code of the program. It starts right after the program's initial memory layout at the defined start address.
- **.data Section:** Initialized global variables are stored in this section.
- **.rodata Section:** Read-only data, such as constants and strings, are stored here.
- **.bss Section:** This section holds uninitialized global variables. At runtime, these are initialized to zero.
- **Stack:** A **kernel stack** is allocated at a predefined location. It typically starts after the `.bss` section and is sized based on your needs (e.g., **8KB**).
- **Heap:** The **heap** follows the stack and is used for dynamic memory allocation during the program's execution. It is usually a large section and can be allocated a fixed amount (e.g., **1MB**).

This structure is designed so that the kernel code can be loaded into the first 1MB of memory, leaving space for dynamic allocations and peripherals.

## 3. **Assembly Code: System Initialization**

The **startup assembly file** is the code responsible for initializing the system, setting up the processor to enter **long mode**, and preparing the system's stack and heap. The primary tasks are as follows:

1. **Global Descriptor Table (GDT) Setup:**
   - The **GDT** defines the memory segments and access permissions for the CPU.
   - In **long mode**, the GDT includes segments for **kernel code** and **kernel data** in 64-bit mode.
   - The system starts by defining a **null descriptor** (not used), followed by a **64-bit code segment** and a **64-bit data segment**.

2. ~~**Transition to 64-bit Long Mode:**~~
   - ~~Initially, the processor runs in **16-bit real mode**, which is the legacy mode for compatibility with older systems.~~
   - ~~To enter **64-bit long mode**, we must modify the **CR0** and **EFER** registers:~~
     - ~~Set the **LME** (Long Mode Enable) bit in the **EFER** register.~~
     - ~~Set the **CR0** register to enable long mode.~~
     - ~~After this setup, we perform a **far jump** to a 64-bit address to complete the transition.~~

3. **Stack and Heap Initialization:**
   - After switching to long mode, the **stack pointer** is initialized to a predefined address (e.g., the top of the stack).
   - Similarly, the **heap** is allocated after the stack section in memory, and its starting point is marked.

4. **Main Kernel Execution:**
   - Once the processor is in long mode, the code proceeds by jumping to the `main()` function (which is defined in the user's C program).

5. **Closing QEMU:**
   - After the `main()` function returns, the QEMU is automatically closed to ensure completion of code execution. This is provided in the assembly code's `complete` section

## 4. **GCC and Building the Bare-Metal System**

To build the final **bare-metal binary** for your x86 system using **GCC**, you can simply use the [Makefile](Makefile) provided in the project.

## 5. **Running on QEMU**

The included script [createBootable.sh](createBootable.sh) creates a ***boot.img*** file with grub on it (ensure you have grub installed, which is present on most linux systems by default). It also mounts your executable binary on it and once the script runs, your boot.img is ready to be used.

To run it, you can simply run **make run** or use the following command:

```bash
qemu-system-x86_64 -drive file=boot.img,format=raw -m 1G -smp 1 -cpu qemu64 -no-reboot -s -S -device qemu-xhci,addr=05.0 -d guest_errors,trace:usb_xhci*,trace:usb_dwc*
```
