#!/bin/sh
exec qemu-system-aarch64 \
  -machine virt \
  -cpu cortex-a72 \
  -smp 4 \
  -m 2G \
  -kernel "$HOME/tinydistro/boot/vmlinuz" \
  -initrd "$HOME/tinydistro/boot/initramfs.img" \
  -append "console=tty1 rdinit=/init" \
  -display vnc=:1 \
  -serial vc \
  -monitor none \
  -no-reboot \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -audiodev alsa,id=audio0 \
  -device intel-hda \
  -device hda-duplex,audiodev=audio0 \
  -device virtio-gpu-pci \
  -device virtio-keyboard-pci
