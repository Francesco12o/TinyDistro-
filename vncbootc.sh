#!/bin/sh

set -eu

KERNEL="$HOME/tinydistro/boot/vmlinuz"
INITRD="$HOME/tinydistro/boot/initramfs.img"

VCPUS=4
RAM=1024
VNC=":0"
XRES=1024
YRES=768

usage() {
    cat <<EOF
TinyDistro VNC Boot Controller

Usage:
  ./vncbootc [options]

Defaults:
  vCPU:        4
  RAM:         1024 MB
  VNC display: :0
  Resolution:  1024x768
  VNC listen:  127.0.0.1:5900

Options:
  --vcpu=N             Set virtual CPU count
  --ram=N              Set RAM in MB
  --vnc=:N             Set VNC display
  --resolution=WxH     Set VirtIO-GPU resolution
  --xres=N              Set horizontal resolution
  --yres=N              Set vertical resolution
  --help                Show this help

Examples:
  ./vncbootc
  ./vncbootc --vcpu=1
  ./vncbootc --vcpu=8
  ./vncbootc --vnc=:1
  ./vncbootc --ram=2048
  ./vncbootc --resolution=1280x720
  ./vncbootc --vcpu=2 --vnc=:1 --ram=2048

VNC:
  :0  -> TCP port 5900
  :1  -> TCP port 5901
  :2  -> TCP port 5902

QEMU VNC listens on the selected display.
The VirtIO GPU provides the virtual display device to TinyDistro.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --vcpu=*)
            VCPUS="${arg#*=}"
            ;;
        --ram=*)
            RAM="${arg#*=}"
            ;;
        --vnc=*)
            VNC="${arg#*=}"
            ;;
        --resolution=*)
            RES="${arg#*=}"
            XRES="${RES%x*}"
            YRES="${RES#*x}"
            ;;
        --xres=*)
            XRES="${arg#*=}"
            ;;
        --yres=*)
            YRES="${arg#*=}"
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "vncbootc: unknown option: $arg"
            echo "Try './vncbootc --help'."
            exit 1
            ;;
    esac
done

case "$VCPUS" in
    ''|*[!0-9]*|0)
        echo "vncbootc: invalid vCPU count: $VCPUS"
        exit 1
        ;;
esac

case "$RAM" in
    ''|*[!0-9]*|0)
        echo "vncbootc: invalid RAM value: $RAM"
        exit 1
        ;;
esac

case "$XRES" in
    ''|*[!0-9]*|0)
        echo "vncbootc: invalid X resolution: $XRES"
        exit 1
        ;;
esac

case "$YRES" in
    ''|*[!0-9]*|0)
        echo "vncbootc: invalid Y resolution: $YRES"
        exit 1
        ;;
esac

case "$VNC" in
    :*)
        ;;
    *)
        echo "vncbootc: VNC display must look like :0, :1, :2..."
        exit 1
        ;;
esac

VNC_DISPLAY="${VNC#:}"
VNC_PORT=$((5900 + VNC_DISPLAY))

echo "TinyDistro VNC Boot"
echo
echo "  Machine:       virt"
echo "  CPU:           cortex-a72"
echo "  vCPU:          $VCPUS"
echo "  RAM:           ${RAM}M"
echo "  Resolution:    ${XRES}x${YRES}"
echo "  VNC display:   $VNC"
echo "  VNC listening: 127.0.0.1:$VNC_PORT"
echo "  Kernel:        $KERNEL"
echo "  Initramfs:     $INITRD"
echo
echo "Starting QEMU..."

exec qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a72 \
    -smp "$VCPUS" \
    -m "${RAM}M" \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -append "console=ttyAMA0 rdinit=/init console=tty1" \
    -device "virtio-gpu-pci,xres=$XRES,yres=$YRES" \
    -device virtio-keyboard-pci \
    -display "vnc=$VNC"


