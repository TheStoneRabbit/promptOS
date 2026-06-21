#!/usr/bin/env bash
# customize_airootfs.sh — runs inside the chroot after pacstrap
# Used to install software that can't be added via packages.x86_64
set -euo pipefail

echo "[promptOS] Running airootfs customization..."

# ── Ollama ────────────────────────────────────────────────────────────────────
# Installed via pacman (the `ollama` package). The Arch package ships its own
# systemd service (runs as the `ollama` user, listens on 127.0.0.1:11434, stores
# models under /var/lib/ollama). No custom binary install or unit file needed.
echo "[promptOS] Enabling pacman-installed ollama service..."
systemctl enable ollama.service 2>/dev/null || true
# No model is baked into the ISO and none is auto-downloaded on boot
# (ollama-warmup is intentionally NOT enabled). promptOS defaults to a cloud
# provider; a local model is only fetched if you explicitly run
# `promptos-model pull` or use the ollama provider.
echo "[promptOS] Ollama service enabled; no local model is downloaded automatically."

# ── Register promptsh as a valid login shell ─────────────────────────────────
# PAM rejects logins (including SSH) whose shell isn't listed in /etc/shells.
echo "[promptOS] Registering promptsh in /etc/shells..."
if ! grep -qxF /usr/local/bin/promptsh /etc/shells 2>/dev/null; then
    echo /usr/local/bin/promptsh >> /etc/shells
fi

# ── Networking: NetworkManager owns both wired + wifi ────────────────────────
# archiso enables systemd-networkd by default, which would fight NetworkManager
# over interfaces and prevent /wifi from working. Disable systemd-networkd and
# enable NetworkManager instead so nmcli/promptos-wifi work on the live ISO.
echo "[promptOS] Switching networking from systemd-networkd to NetworkManager..."
systemctl disable systemd-networkd.service 2>/dev/null || true
systemctl disable systemd-networkd.socket 2>/dev/null || true
systemctl mask  systemd-networkd.service 2>/dev/null || true
systemctl enable NetworkManager.service 2>/dev/null || true
# The static 20-wired.network drop-in only applies to systemd-networkd; remove it
# so NetworkManager has unambiguous ownership of the wired interface.
rm -f /etc/systemd/network/20-wired.network

# ── Pre-compile Python bytecode for faster startup ────────────────────────────
echo "[promptOS] Pre-compiling Python bytecode..."
python -m compileall -q /usr/local/lib/promptos/ 2>/dev/null || true

# ── Cleanup ───────────────────────────────────────────────────────────────────
echo "[promptOS] Airootfs customization complete."
