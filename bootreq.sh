#!/usr/bin/env bash

set -e

echo "Select your host operating system:"
echo "1) Debian"
echo "2) Ubuntu"
echo "3) Arch Linux"
echo "4) Fedora"

read -p "Choice: " choice

install_debian() {
    sudo apt update
    sudo apt install -y qemu-system-x86 qemu-system-arm qemu-utils ovmf grub-common
}

install_ubuntu() {
    sudo apt update
    sudo apt install -y qemu-system-x86 qemu-system-arm qemu-utils ovmf grub-common
}

install_arch() {
    sudo pacman -Syu --needed qemu-desktop qemu-system-x86 qemu-system-aarch64 qemu-img ovmf grub
}

install_fedora() {
    sudo dnf install -y @virtualization qemu-system-x86 qemu-system-aarch64 qemu-img edk2-ovmf grub2-tools
}

case "$choice" in
    1)
        install_debian
        ;;
    2)
        install_ubuntu
        ;;
    3)
        install_arch
        ;;
    4)
        install_fedora
        ;;
    *)
        echo "Invalid selection"
        exit 1
        ;;
esac

echo "Requirements installed."
echo "You can now boot your custom kernel and initramfs with QEMU."
