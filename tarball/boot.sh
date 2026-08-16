#!/bin/sh

qemu-system-aarch64 \
  -machine virt \
  -cpu cortex-a72 \
  -m 1024 \
  -kernel boot/vmlinuz \
  -initrd boot/initramfs.img \
  -append "console=ttyAMA0 rdinit=/init" \
  -nographic
