# x86-QEMU-Linker

A linker script to run bare-metal code on x86 system using QEMU
---

The project explores getting bare-metal C code to run on x86 system using [QEMU](). To learn more about the [x86 Support for QEMU](https://www.qemu.org/docs/master/system/target-i386.html) (via i440x PC), you can check the official website [here](https://www.qemu.org/docs/master/system/i386/pc.html)

## Implementation Specifics

- The current implementation depends on i440x PC (qemu device type: pc) for implementation. There are [other types](https://www.qemu.org/docs/master/system/target-i386.html#board-specific-documentation) of boards supported too.

- QEMU has [two ways](https://www.qemu.org/docs/master/system/i386/cpu.html#two-ways-to-configure-cpu-models-with-qemu-kvm) to configure CPU model for your x86 VM. Here is a short description:
  - QEMU supports [multiple CPU architectures](https://www.qemu.org/docs/master/system/i386/cpu.html). They depend on host systems (the systems which you run QEMU on).
    - There is preferred support for [Intel](https://www.qemu.org/docs/master/system/i386/cpu.html#preferred-cpu-models-for-intel-x86-hosts) based hosts
    - There is preferred support for [AMD](https://www.qemu.org/docs/master/system/i386/cpu.html#preferred-cpu-models-for-amd-x86-hosts) based hosts.

  - By default, QEMU provides [CPU models that can run on any x86 device](https://www.qemu.org/docs/master/system/i386/cpu.html#default-x86-cpu-models)

  - It is also possible to do [Host pass-through](https://www.qemu.org/docs/master/system/i386/cpu.html#preferred-cpu-models-for-intel-x86-hosts:~:text=%EF%83%81-,Host%20passthrough)

- There is a [Linker Script](https://wiki.osdev.org/Linker_Scripts) (Here is more info on [What is a Linker?](https://en.wikipedia.org/wiki/Linker_(computing))) for configuring how the program is organized/laid-out. The linker script in this repo defines how your bare-metal "C" code will be structured.

- Since we are running a bare-metal program, we are going to use an assembly program to define startup behavior of our x86 VM.

- The code is compiled using [GCC x86](https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html) build options. To make it bare-metal, we'll be using the flags `-ffreestanding -fno-PIE -nostartfiles -nostdlib` which tell the following information to the compiler:
  - Here’s a simple summary of each flag:
    - `-ffreestanding`: Assumes no standard library or runtime environment is available.
    - `-fno-PIE`**: Disables position-independent executables (PIE), which means the code has fixed memory addresses.
    - `-nostartfiles`: Prevents the inclusion of standard startup code (like `crt0.o`), which sets up the runtime environment.
    - `-nostdlib`:  Tells the compiler not to link against the standard C library or other standard libraries.

## Build information

- The code includes a *[Makefile](Makefile)* (A config used by the [Make](https://en.wikipedia.org/wiki/Make_(software)) tool) to build the system. The main program is named **main.c** by default (but can be changed in the Makefile).

- The code is built in steps - where the main is built as an [object](https://en.wikipedia.org/wiki/Object_file), then linked together using the linker and the startup code.

- Finally, everything is properly built and a *x86-bare.dsp* image is created. This image can now be run on QEMU.

## Running on QEMU

To run the code on QEMU, simply use `-kernel x86-bare.dsp`

## Technical Document

The **[TECHNICALS](TECHNICALS.md)** file contains all the technical information regarding the whole project. Feel free to check it out!
