#!/bin/bash
#
# Check if boot.img exists or not. If it does not, create a new one
if [ -f "boot.img" ]; then
  echo ""
else
  echo "boot.img does not exist. Creating a new one"
  # Create a blank disk of size 10 MB
  dd if=/dev/zero of=boot.img bs=512K count=60
  # Mount it
  sudo losetup /dev/loop69 boot.img
  # Create partition
  sudo gdisk /dev/loop69 <<EOF
o
y
n
1

+15M
8300
n
2


EF02
w
y
EOF
  # Scan for new partitions
  sudo partprobe /dev/loop69
  # Format them
  sudo mkfs.ext4 /dev/loop69p1
  sudo mkfs.fat -F 32 /dev/loop69p2
  # Mount partition to install grub
  sudo mount /dev/loop69p1 /mnt/boot
  sudo mkdir -p /mnt/boot/boot/grub
  # Install GRUB bootloader
  sudo grub-install --target=i386-pc --boot-directory=/mnt/boot/boot --no-floppy /dev/loop69
  # Write config
  sudo bash -c 'cat > /mnt/boot/boot/grub/grub.cfg <<EOF
set default=0
set timeout=0
menuentry "DSPs Bare-Metal Kernel" {
    multiboot /boot/x86-bare.dsp
}
EOF'
  # Unmount and cleanup
  sudo umount /mnt/boot
  sudo losetup -d /dev/loop69
  # Print completion message
  echo Completed Creation of boot.img
fi

if grub-file --is-x86-multiboot x86-bare.dsp; then
  echo multiboot confirmed. setting up boot.img
  # loop-setup
  sudo losetup /dev/loop69 boot.img
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
  echo Successfully Updated boot.img
else
  echo the file is not multiboot
fi
