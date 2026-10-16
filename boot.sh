#!/usr/bin/env bash
set -Eeuo pipefail

# TinyDistro configurable launcher
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

CUSTOM_BOOT_DIR="${CUSTOM_BOOT_DIR:-$BASE_DIR/boot}"
CHROOT_DIR="${CHROOT_DIR:-$BASE_DIR/initramfs}"
CHROOT_APPPEND="${CHROOT_APPPEND:-/bin/sh}"
CPU_CORES="${CPU_CORES:-4}"
RAM_MEM="${RAM_MEM:-2G}"
INITRAMFS_NAME="${INITRAMFS_NAME:-initramfs}"
KERNEL_NAME="${KERNEL_NAME:-vmlinuz}"
INITRAMFS_PACK_DIR="${INITRAMFS_PACK_DIR:-$CUSTOM_BOOT_DIR}"
INITRAMFS_PACK_NAME="${INITRAMFS_PACK_NAME:-initramfs.img}"
KERNEL_APPEND="${KERNEL_APPEND:-console=ttyAMA0 rdinit=/init}"
DEBUG_LOGS_DIR="${DEBUG_LOGS_DIR:-$BASE_DIR/logs}"

MACHINE="${MACHINE:-virt}"
CPU_MODEL="${CPU_MODEL:-cortex-a72}"
VNC_DISPLAY="${VNC_DISPLAY:-:1}"

SOUND=1
NETWORK=1
BOOT_ONLY_KERNEL=0
RAWBOOT=0
DO_CHROOT=0
PACK_INITRAMFS=0
PACK_SNAPSHOT=0
DEBUG_LOGS=0
DEBUG_TIMESTAMPS=0
INSTALL_DEPENDENCIES=0

INITRAMFS_PATH="$INITRAMFS_PACK_DIR/$INITRAMFS_PACK_NAME"
KERNEL_PATH="$CUSTOM_BOOT_DIR/$KERNEL_NAME"

usage() {
    printf '%s\n' \
        "TinyDistro boot.sh" \
        "" \
        "Usage: ./boot.sh [options]" \
        "" \
        "Options:" \
        "  --help                   Show this help" \
        "  --show-defs              Show configuration defaults" \
        "  --boot-only-kernel       Boot without an initramfs" \
        "  -rawboot                 Boot directly with QEMU" \
        "  --chroot                 Enter the initramfs tree using chroot" \
        "  --pack-initramfs         Pack the initramfs and exit" \
        "  --pack-snapshot          Pack rootfs.tar.gz and the initramfs" \
        "  --no-sound               Disable QEMU sound devices" \
        "  --no-network             Disable QEMU networking" \
        "  --installdependecies     Install common build/boot dependencies" \
        "  --debug-logs             Save boot output to a log" \
        "  --debug-logs-timestrap   Add a timestamp to the log filename" \
        "" \
        "Environment overrides:" \
        "  CUSTOM_BOOT_DIR, CHROOT_DIR, CHROOT_APPPEND" \
        "  CPU_CORES, RAM_MEM, INITRAMFS_NAME, KERNEL_NAME" \
        "  INITRAMFS_PACK_DIR, INITRAMFS_PACK_NAME, KERNEL_APPEND" \
        "  DEBUG_LOGS_DIR, VNC_DISPLAY, MACHINE, CPU_MODEL"
}

show_defs() {
    printf 'CUSTOM_BOOT_DIR=%s\n' "$CUSTOM_BOOT_DIR"
    printf 'CHROOT_DIR=%s\n' "$CHROOT_DIR"
    printf 'CHROOT_APPPEND=%s\n' "$CHROOT_APPPEND"
    printf 'CPU_CORES=%s\n' "$CPU_CORES"
    printf 'RAM_MEM=%s\n' "$RAM_MEM"
    printf 'INITRAMFS_NAME=%s\n' "$INITRAMFS_NAME"
    printf 'KERNEL_NAME=%s\n' "$KERNEL_NAME"
    printf 'INITRAMFS_PACK_DIR=%s\n' "$INITRAMFS_PACK_DIR"
    printf 'INITRAMFS_PACK_NAME=%s\n' "$INITRAMFS_PACK_NAME"
    printf 'KERNEL_APPEND=%s\n' "$KERNEL_APPEND"
    printf 'DEBUG_LOGS_DIR=%s\n' "$DEBUG_LOGS_DIR"
    printf 'VNC_DISPLAY=%s\n' "$VNC_DISPLAY"
    printf 'MACHINE=%s\n' "$MACHINE"
    printf 'CPU_MODEL=%s\n' "$CPU_MODEL"
}

pack_initramfs() {
    if [[ ! -d "$CHROOT_DIR" ]]; then
        printf 'Error: initramfs directory not found: %s\n' "$CHROOT_DIR" >&2
        exit 1
    fi

    mkdir -p "$INITRAMFS_PACK_DIR"
    printf 'Packing %s -> %s\n' "$CHROOT_DIR" "$INITRAMFS_PATH"

    (
        cd "$CHROOT_DIR"
        find . -print0 |
            cpio --null -o --format=newc 2>/dev/null |
            gzip -9 > "$INITRAMFS_PATH"
    )

    printf 'Initramfs packed successfully.\n'
}

pack_snapshot() {
    mkdir -p "$BASE_DIR"
    tar -czf "$BASE_DIR/rootfs.tar.gz" -C "$CHROOT_DIR" .
    pack_initramfs
    printf 'Snapshot created: %s/rootfs.tar.gz\n' "$BASE_DIR"
}

install_dependencies() {
    if ! command -v apt-get >/dev/null 2>&1; then
        printf 'apt-get not found; install QEMU, cpio, gzip and nano manually.\n' >&2
        exit 1
    fi

    apt-get update
    apt-get install -y qemu-system-arm qemu-utils cpio gzip nano
}

while (($#)); do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --show-defs) show_defs; exit 0 ;;
        --boot-only-kernel) BOOT_ONLY_KERNEL=1 ;;
        -rawboot) RAWBOOT=1 ;;
        --chroot) DO_CHROOT=1 ;;
        --pack-initramfs) PACK_INITRAMFS=1 ;;
        --pack-snapshot) PACK_SNAPSHOT=1 ;;
        --no-sound) SOUND=0 ;;
        --no-network) NETWORK=0 ;;
        --debug-logs) DEBUG_LOGS=1 ;;
        --debug-logs-timestrap)
            DEBUG_LOGS=1
            DEBUG_TIMESTAMPS=1
            ;;
        --installdependecies) INSTALL_DEPENDENCIES=1 ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage
            exit 2
            ;;
    esac
    shift
done

if ((INSTALL_DEPENDENCIES)); then
    install_dependencies
    exit 0
fi

if ((PACK_INITRAMFS)); then
    pack_initramfs
    exit 0
fi

if ((PACK_SNAPSHOT)); then
    pack_snapshot
    exit 0
fi

if ((DO_CHROOT)); then
    if [[ $EUID -ne 0 ]]; then
        printf 'Please run chroot mode as root.\n' >&2
        exit 1
    fi
    exec chroot "$CHROOT_DIR" "$CHROOT_APPPEND"
fi

if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
    printf 'Error: qemu-system-aarch64 is not installed.\n' >&2
    exit 1
fi

if [[ ! -f "$KERNEL_PATH" ]]; then
    printf 'Error: kernel not found: %s\n' "$KERNEL_PATH" >&2
    exit 1
fi

if ((!BOOT_ONLY_KERNEL)) && [[ ! -f "$INITRAMFS_PATH" ]]; then
    printf 'Error: initramfs not found: %s\n' "$INITRAMFS_PATH" >&2
    printf 'Run ./boot.sh --pack-initramfs first.\n' >&2
    exit 1
fi

QEMU_ARGS=(
    -machine "$MACHINE"
    -cpu "$CPU_MODEL"
    -smp "$CPU_CORES"
    -m "$RAM_MEM"
    -kernel "$KERNEL_PATH"
    -append "$KERNEL_APPEND"
    -vnc "$VNC_DISPLAY"
    -serial mon:stdio
    -no-reboot
)

if ((!BOOT_ONLY_KERNEL)); then
    QEMU_ARGS+=( -initrd "$INITRAMFS_PATH" )
fi

if ((NETWORK)); then
    QEMU_ARGS+=(
        -netdev user,id=net0
        -device virtio-net-pci,netdev=net0
    )
fi

if ((SOUND)); then
    # QEMU sound output depends on the host audio backend and guest drivers.
    QEMU_ARGS+=(
        -audiodev alsa,id=audio0
        -device intel-hda
        -device hda-duplex,audiodev=audio0
    )
fi

printf '%s\n' "Starting TinyDistro..." \
    "CPU cores: $CPU_CORES" \
    "RAM: $RAM_MEM" \
    "VNC: localhost${VNC_DISPLAY}" \
    "Networking: $([[ $NETWORK == 1 ]] && printf enabled || printf disabled)" \
    "Sound: $([[ $SOUND == 1 ]] && printf enabled || printf disabled)"

if ((DEBUG_LOGS)); then
    mkdir -p "$DEBUG_LOGS_DIR"
    if ((DEBUG_TIMESTAMPS)); then
        LOG_FILE="$DEBUG_LOGS_DIR/boot-$(date +%Y%m%d-%H%M%S).log"
    else
        LOG_FILE="$DEBUG_LOGS_DIR/boot.log"
    fi
    printf 'Logging to %s\n' "$LOG_FILE"
    qemu-system-aarch64 "${QEMU_ARGS[@]}" 2>&1 | tee "$LOG_FILE"
else
    qemu-system-aarch64 "${QEMU_ARGS[@]}"
fi
