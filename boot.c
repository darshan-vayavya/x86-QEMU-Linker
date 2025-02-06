/**
 * @file boot.c
 * @author Darshan(@thisisthedarshan) <darshanp@vayavyalabs.com>
 * This file just displays a boot message onto qemu monitor
 */

#include <vga.h>

void display_boot() {
    clear();
    print(" _____   \n");
    print("|  __ \\ \n");
    print("| |  | | \n");
    print("| |  | | \n");
    print("| |__| | \n");
    print("|_____/  \n");
    newline();
    print("Welcome to x86 Bare Metal Code");
    /* Small delay before we continue */
    for (long x = 0; x < 0xDDDDDD; x++);
}

void display_end() {
    clear();
    print(" _____   \n");
    print("|  __ \\ \n");
    print("| |  | | \n");
    print("| |  | | \n");
    print("| |__| | \n");
    print("|_____/  \n");
    newline();
    print("Thank You for using x86 Bare Metal System\n");
    print("We will now exit :D");
    /* Small delay before we continue */
    for (long x = 0; x < 0xDDDDDD; x++);
}