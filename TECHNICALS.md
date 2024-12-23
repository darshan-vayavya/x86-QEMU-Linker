# Technical Documentation: Bootstrapping a Bare-Metal x86 System with 1GB RAM

This document explains the process of bootstrapping a **bare-metal x86 system** with **1GB of RAM**. It details the necessary setup, including the **linker script**, **assembly file**, **transition to long mode**, **memory layout**, and the role of **GDT** and **paging**. The final goal is to create a system that runs on an **x86 QEMU environment** using **GCC** for compilation.

## 1. Overview of the System Architecture

The system will run in **64-bit long mode** (as opposed to 16-bit real mode or 32-bit protected mode) with a **flat memory model**. The **long mode** allows the processor to address a large memory space in a simplified and linear fashion. This mode is ideal for modern bare-metal systems as it simplifies memory management and allows the system to use the full capabilities of the x86-64 architecture.

The system will use **1GB of RAM**, and this RAM will be allocated across different regions for the **kernel code**, **data**, **heap**, **stack**, and **free memory**. The **memory-mapped I/O** space (for peripherals like xHCI) will also be handled separately.

## 2. **Linker Script and Memory Layout**

The **linker script** is essential for defining how the compiled code should be laid out in memory. It ensures that sections like `.text`, `.data`, `.bss`, the **stack**, and **heap** are placed at the right locations. Here's the key breakdown of the memory layout:

- **Program Start (0x100000):** The program begins at `0x100000` (1MB) to allow for any BIOS or bootloader requirements.
- **.text Section:** This section contains the executable code of the program. It starts right after the program's initial memory layout at the defined start address.
- **.data Section:** Initialized global variables are stored in this section.
- **.rodata Section:** Read-only data, such as constants and strings, are stored here.
- **.bss Section:** This section holds uninitialized global variables. At runtime, these are initialized to zero.
- **Stack:** A **kernel stack** is allocated at a predefined location. It typically starts after the `.bss` section and is sized based on your needs (e.g., **8KB**).
- **Heap:** The **heap** follows the stack and is used for dynamic memory allocation during the program's execution. It is usually a large section and can be allocated a fixed amount (e.g., **1MB**).
- **Free Memory:** The remaining memory is reserved as **free RAM**, and the system is configured to ensure that it does not overlap with the heap or stack.

This structure is designed so that the kernel code can be loaded into the first 1MB of memory, leaving space for dynamic allocations and peripherals.

## 3. **Assembly Code: System Initialization**

The **startup assembly file** is the code responsible for initializing the system, setting up the processor to enter **long mode**, and preparing the system's stack and heap. The primary tasks are as follows:

1. **Global Descriptor Table (GDT) Setup:**
   - The **GDT** defines the memory segments and access permissions for the CPU.
   - In **long mode**, the GDT includes segments for **kernel code** and **kernel data** in 64-bit mode.
   - The system starts by defining a **null descriptor** (not used), followed by a **64-bit code segment** and a **64-bit data segment**.

2. **Transition to 64-bit Long Mode:**
   - Initially, the processor runs in **16-bit real mode**, which is the legacy mode for compatibility with older systems.
   - To enter **64-bit long mode**, we must modify the **CR0** and **EFER** registers:
     - Set the **LME** (Long Mode Enable) bit in the **EFER** register.
     - Set the **CR0** register to enable long mode.
     - After this setup, we perform a **far jump** to a 64-bit address to complete the transition.

3. **Stack and Heap Initialization:**
   - After switching to long mode, the **stack pointer** is initialized to a predefined address (e.g., the top of the stack).
   - Similarly, the **heap** is allocated after the stack section in memory, and its starting point is marked.

4. **Main Kernel Execution:**
   - Once the processor is in long mode, the code proceeds by jumping to the `main()` function (which is defined in the user's C program).

5. **Infinite Loop:**
   - After the `main()` function returns, an infinite loop is entered to keep the system running in a consistent state. This prevents the program from exiting unexpectedly.

## 4. **Transition to 64-bit Long Mode: Why It's Necessary**

In modern x86 processors, **long mode** (64-bit mode) offers several advantages over **real mode** or **protected mode**:

- **Flat Memory Model:** In long mode, the system can access all of the available physical memory as a single contiguous address space. This removes the need for complex memory management mechanisms that are needed in 32-bit mode.
- **Larger Address Space:** Long mode allows access to a far larger address space (up to 256TB), whereas 32-bit systems are limited to 4GB of addressable memory.
- **Simplified Segmentation:** Long mode uses a flat memory model, so the need for segment descriptors (which are used in 16-bit and 32-bit modes) is minimized, simplifying memory management.

## 5. **Disabling Virtual Memory (Paging)**

Virtual memory is a system in which the physical memory is abstracted into a larger address space using a mechanism called **paging**. However, for a bare-metal system running directly on hardware (without an OS), **paging** and **virtual memory** management are not needed. In fact, enabling paging could complicate direct access to physical memory, such as the memory-mapped I/O region for **xHCI** or other peripherals.

- **Disabling Paging:** In the assembly code, the transition to long mode happens without enabling **paging**. This ensures that physical addresses are directly mapped and used by the CPU, rather than being translated through a page table.

## 6. **GCC and Building the Bare-Metal System**

To build the final **bare-metal binary** for your x86 system using **GCC**, you can simply use the [Makefile](Makefile) provided in the project.

## 7. Conclusion

The process outlined in this documentation allows you to create a **bare-metal system** for the **x86 architecture** that runs on **QEMU**. It covers the initialization of the system's hardware, the switch to **64-bit long mode**, the setup of the **Global Descriptor Table (GDT)**, and the allocation of **stack**, **heap**, and **free memory**. The system is built using **GCC** for compiling both **assembly** and **C** code, with a **linker script** to manage memory layout and section placement. Finally, the system is capable of interacting with peripherals like the **xHCI** through **memory-mapped I/O** regions.

This approach provides a foundation for creating **bare-metal kernels** or **low-level system software** that directly interfaces with the hardware without the need for an operating system or virtual memory management.
