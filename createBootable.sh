#!/bin/bash
# Written by Darshan(@thisisthedarshan) <darshanp@vayavyalabs.com>
# This bash script is used to create a bootable image file that can
# be run on QEMU. The file will need to be run as sudo user since it
# involves mounting and unmounting the image file onto the file-system
# The script works as follows -
# - Checks if the file is boot.dsp file is present.
#   - If the File is not present - Create a new file of size 30 MB
#   - Mount the file and create new GPT partition
#   - Update filesystem to recognize the new partition
#   - Format this newly created partition using ext4 - for grub
#   - Mount it onto accessible filesystem and install grub and grub config
#   - Unmount
# - If the boot.dsp file exists, the script does the following:
#   - Mount the image file onto accessible filesystem
#   - Remove the old elf file - x86-bare.dsp
#   - Load the updated elf file.
#   - Unmount the boot.dsp from the filesystem to complete process.

if [ -f "boot.dsp" ]; then
  echo "Found boot.dsp"
else
  echo "boot.dsp does not exist. Creating a new one"
  # Create a blank disk of size 40 MB
  dd if=/dev/zero of=boot.dsp bs=512K count=80
  # Mount it
  sudo losetup /dev/loop69 boot.dsp
  # Create partition
  sudo gdisk /dev/loop69 <<EOF
o
y
n
1

+30MB
8300
n
2


EF02
w
y
EOF
  # Scan for new partition
  sudo partprobe /dev/loop69
  # Format it
  sudo mkfs.ext4 /dev/loop69p1
  sudo mkfs.vfat -F32 /dev/loop69p2
  # Mount partition to install grub
  sudo mount /dev/loop69p1 /mnt/boot
  sudo mkdir -p /mnt/boot/boot/grub
  # Install GRUB bootloader
  sudo grub-install --target=i386-pc --boot-directory=/mnt/boot/boot --no-floppy /dev/loop69
  # Write config
  sudo bash -c 'cat > /mnt/boot/boot/grub/grub.cfg <<EOF
set default=0
set timeout=1
menuentry "DSPs Bare-Metal Kernel" {
    multiboot /boot/x86-bare.dsp
}
EOF'
  # Unmount and cleanup
  sudo umount /mnt/boot
  sudo losetup -d /dev/loop69
  # Print completion message
  echo Completed Creation of boot.dsp
fi

if grub-file --is-x86-multiboot x86-bare.dsp; then
  echo multiboot confirmed. setting up boot.dsp
  # loop-setup
  sudo losetup /dev/loop69 boot.dsp
  sudo partprobe /dev/loop69
  # Mount
  sudo mkdir -p /mnt/boot
  sudo mount /dev/loop69p1 /mnt/boot
  # Clean old one and load new one
  sudo rm -f /mnt/boot/boot/x86-bare.dsp
  sudo cp x86-bare.dsp /mnt/boot/boot/
  # Cleanup
  sudo umount /mnt/boot/
  sudo losetup -d /dev/loop69
  # Display success
  echo Successfully Updated boot.dsp
else
  echo the file is not multiboot
fi
