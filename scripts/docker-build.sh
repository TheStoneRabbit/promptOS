#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="/build/profile"
OUTPUT_DIR="/output"
WORK_DIR="/tmp/archiso-work"

echo "[promptOS] Starting ISO build..."
echo "[promptOS] Profile: $PROFILE_DIR"
echo "[promptOS] Output:  $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR" "$WORK_DIR"

# --- Optionally bake API key(s) / provider into the profile (from build.sh) ---
# These come in as container env vars so the key never touches the repo working
# tree or Docker image layers. The resulting ISO does contain the key.
KEYS_FILE="$PROFILE_DIR/airootfs/etc/promptos/keys"
CONFIG_FILE="$PROFILE_DIR/airootfs/etc/promptos/config"

set_kv() {  # file key value
    local file="$1" key="$2" val="$3"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if grep -qE "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$file"
    else
        echo "${key}=${val}" >> "$file"
    fi
}

baked=""
if [ -n "${PROMPTOS_BUILD_OPENAI_KEY:-}" ]; then
    set_kv "$KEYS_FILE" OPENAI_API_KEY "$PROMPTOS_BUILD_OPENAI_KEY"; baked="openai"
fi
if [ -n "${PROMPTOS_BUILD_CLAUDE_KEY:-}" ]; then
    set_kv "$KEYS_FILE" ANTHROPIC_API_KEY "$PROMPTOS_BUILD_CLAUDE_KEY"; baked="claude"
fi
if [ -n "${PROMPTOS_BUILD_GROQ_KEY:-}" ]; then
    set_kv "$KEYS_FILE" GROQ_API_KEY "$PROMPTOS_BUILD_GROQ_KEY"; baked="groq"
fi
if [ -n "${PROMPTOS_BUILD_PROVIDER:-}" ]; then
    set_kv "$CONFIG_FILE" PROMPTOS_PROVIDER "$PROMPTOS_BUILD_PROVIDER"
elif [ -n "$baked" ]; then
    set_kv "$CONFIG_FILE" PROMPTOS_PROVIDER "$baked"
fi
if [ -n "$baked" ]; then
    echo "[promptOS] Baked API key into ISO; $(grep '^PROMPTOS_PROVIDER=' "$CONFIG_FILE")"
fi

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
