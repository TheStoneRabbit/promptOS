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

# Ollama is now installed via pacman (the `ollama` package), so no manual
# binary caching is needed — pacman handles installation in the chroot.

# mkinitcpio is patched inside the chroot via a pacman hook:
# airootfs/etc/pacman.d/hooks/80-patch-mkinitcpio-container.hook
# It runs after mkinitcpio installs but before the kernel's 90-mkinitcpio-install.hook,
# fixing the overlay root detection failure that breaks initramfs builds in Docker.

# Run archiso
mkarchiso -v \
    -w "$WORK_DIR" \
    -o "$OUTPUT_DIR" \
    "$PROFILE_DIR"

echo "[promptOS] Build complete. ISO written to $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.iso 2>/dev/null || echo "[promptOS] Warning: no ISO found in output dir"
