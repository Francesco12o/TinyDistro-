#!/bin/sh

qemu-system-aarch64 \
-machine virt \
-cpu cortex-a72 \
-m 1024 \
-kernel ~/tinydistro/boot/vmlinuz \
-initrd ~/tinydistro/boot/initramfs.img \
-append "console=ttyAMA0 rdinit=/init console=tty1" \
-device virtio-gpu-pci,xres=1024,yres=768 \
-display vnc=:0
