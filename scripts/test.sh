#!/usr/bin/env bash
# test.sh — boot the latest promptOS ISO in QEMU
#
# Modes:
#   ./scripts/test.sh                 live boot (BIOS/syslinux)        — quick smoke test
#   ./scripts/test.sh --uefi          live boot (UEFI/systemd-boot)
#   ./scripts/test.sh --install       UEFI + persistent disk          — test the installer
#   ./scripts/test.sh --install --fresh   wipe the disk first
#
# Options:
#   --iso <path>    boot a specific ISO (default: newest in dist/)
#   --disk <path>   disk image for --install (default: dist/promptos-test.qcow2)
#   --size <N>      disk size when creating, e.g. 20G (default: 20G)
#   --fresh         recreate the disk image before booting
#
# Note: host is Apple Silicon, so the x86_64 ISO runs under full emulation
# (no hardware accel for cross-arch). Expect it to be slow but functional.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
SSH_PORT=2222

FW_DIR="/opt/homebrew/share/qemu"
FW_CODE="$FW_DIR/edk2-x86_64-code.fd"
FW_VARS_TEMPLATE="$FW_DIR/edk2-i386-vars.fd"

MODE="live"          # live | install
FIRMWARE="bios"      # bios | uefi
ISO=""
DISK="$DIST_DIR/promptos-test.qcow2"
DISK_SIZE="20G"
FRESH=0

while [ $# -gt 0 ]; do
    case "$1" in
        --uefi)    FIRMWARE="uefi"; shift ;;
        --install) MODE="install"; FIRMWARE="uefi"; shift ;;
        --fresh)   FRESH=1; shift ;;
        --iso)     ISO="$2"; shift 2 ;;
        --disk)    DISK="$2"; shift 2 ;;
        --size)    DISK_SIZE="$2"; shift 2 ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$ISO" ]; then
    ISO=$(ls -t "$DIST_DIR"/*.iso 2>/dev/null | head -1 || true)
fi
if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
    echo "No ISO found in $DIST_DIR. Run scripts/build.sh first." >&2
    exit 1
fi

QEMU_ARGS=(
    -m 4096
    -smp 4
    -cdrom "$ISO"
    -boot d
    -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22
    -device e1000,netdev=net0
    -object rng-random,id=rng0,filename=/dev/urandom
    -device virtio-rng-pci,rng=rng0
    -display cocoa,show-cursor=on
)

# --- UEFI firmware (required for installer: bootctl/systemd-boot needs UEFI) ---
if [ "$FIRMWARE" = "uefi" ]; then
    if [ ! -f "$FW_CODE" ]; then
        echo "UEFI firmware not found: $FW_CODE" >&2
        echo "Install QEMU via Homebrew (brew install qemu)." >&2
        exit 1
    fi
    VARS="$DIST_DIR/promptos-uefi-vars.fd"
    if [ ! -f "$VARS" ]; then
        cp "$FW_VARS_TEMPLATE" "$VARS"   # writable NVRAM copy (persists boot entries)
    fi
    QEMU_ARGS+=(
        -drive "if=pflash,format=raw,readonly=on,file=$FW_CODE"
        -drive "if=pflash,format=raw,file=$VARS"
    )
fi

# --- Persistent disk (installer target) ---
if [ "$MODE" = "install" ]; then
    if [ "$FRESH" = "1" ] && [ -f "$DISK" ]; then
        echo "==> Removing existing disk: $DISK"
        rm -f "$DISK"
    fi
    if [ ! -f "$DISK" ]; then
        echo "==> Creating $DISK_SIZE disk: $DISK"
        qemu-img create -f qcow2 "$DISK" "$DISK_SIZE" >/dev/null
    fi
    QEMU_ARGS+=(-drive "if=virtio,format=qcow2,file=$DISK")
fi

echo "==> Booting: $ISO"
echo "    mode=$MODE firmware=$FIRMWARE"
[ "$MODE" = "install" ] && echo "    disk=$DISK (appears as /dev/vda in the VM)"
echo ""
echo "  QEMU controls:  Ctrl+Alt+G release mouse · Ctrl+Alt+F fullscreen"
echo "  SSH (once booted):  ssh root@localhost -p $SSH_PORT"
echo ""

exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
