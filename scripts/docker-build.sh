#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="/build/profile"
OUTPUT_DIR="/output"
WORK_DIR="/tmp/archiso-work"

echo "[promptOS] Starting ISO build..."
echo "[promptOS] Profile: $PROFILE_DIR"
echo "[promptOS] Output:  $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR" "$WORK_DIR"

# Sync package databases from the pinned archive snapshot
echo "[promptOS] Syncing package databases..."
pacman -Sy --noconfirm --disable-sandbox

# Copy cached Ollama binary into airootfs before build (saves ~100MB download).
# We do NOT copy the model — it's downloaded on first use via promptos-model.
if [ -f "/var/lib/ollama/bin/ollama" ]; then
    echo "[promptOS] Using cached Ollama binary from volume..."
    mkdir -p "$PROFILE_DIR/airootfs/usr/local/bin"
    cp /var/lib/ollama/bin/ollama "$PROFILE_DIR/airootfs/usr/local/bin/ollama"
    chmod +x "$PROFILE_DIR/airootfs/usr/local/bin/ollama"
fi

# mkinitcpio is patched inside the chroot via a pacman hook:
# airootfs/etc/pacman.d/hooks/80-patch-mkinitcpio-container.hook
# It runs after mkinitcpio installs but before the kernel's 90-mkinitcpio-install.hook,
# fixing the overlay root detection failure that breaks initramfs builds in Docker.

# Run archiso
mkarchiso -v \
    -w "$WORK_DIR" \
    -o "$OUTPUT_DIR" \
    "$PROFILE_DIR"

# Cache Ollama binary to volume for future builds (skips re-download).
if [ -f "$WORK_DIR/x86_64/airootfs/usr/local/bin/ollama" ] && [ ! -f "/var/lib/ollama/bin/ollama" ]; then
    echo "[promptOS] Caching Ollama binary to volume..."
    mkdir -p /var/lib/ollama/bin
    cp "$WORK_DIR/x86_64/airootfs/usr/local/bin/ollama" /var/lib/ollama/bin/ollama
fi

echo "[promptOS] Build complete. ISO written to $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.iso 2>/dev/null || echo "[promptOS] Warning: no ISO found in output dir"
