#!/bin/sh

qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a72 \
    -m 1024 \
    -kernel ~/tinydistro/boot/vmlinuz \
    -initrd ~/tinydistro/boot/initramfs.img \
    -append "console=ttyAMA0 rdinit=/init"
