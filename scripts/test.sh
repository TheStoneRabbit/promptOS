#!/usr/bin/env bash
# test.sh — boot the latest promptOS ISO in QEMU
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
SSH_PORT=2222

ISO=$(ls -t "$DIST_DIR"/*.iso 2>/dev/null | head -1)

if [ -z "$ISO" ]; then
    echo "No ISO found in $DIST_DIR. Run scripts/build.sh first."
    exit 1
fi

echo "==> Booting: $ISO"
echo ""
echo "  QEMU controls:"
echo "    Ctrl+Alt+G   — release mouse"
echo "    Ctrl+Alt+F   — toggle fullscreen"
echo ""
echo "  Copy/paste via SSH (once booted):"
echo "    ssh root@localhost -p $SSH_PORT"
echo ""

qemu-system-x86_64 \
    -m 4096 \
    -smp 4 \
    -cdrom "$ISO" \
    -boot d \
    -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22 \
    -device e1000,netdev=net0 \
    -object rng-random,id=rng0,filename=/dev/urandom \
    -device virtio-rng-pci,rng=rng0 \
    -display cocoa,show-cursor=on
