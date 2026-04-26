#!/usr/bin/env bash
# customize_airootfs.sh — runs inside the chroot after pacstrap
# Used to install software that can't be added via packages.x86_64
set -euo pipefail

echo "[promptOS] Running airootfs customization..."

# ── Ollama ────────────────────────────────────────────────────────────────────
# Binary is pre-copied from Docker volume by docker-build.sh, skip download if present
echo "[promptOS] Checking for Ollama binary at /usr/local/bin/ollama..."
ls -la /usr/local/bin/ollama 2>&1 || true
if [ -f /usr/local/bin/ollama ]; then
    chmod +x /usr/local/bin/ollama
    echo "[promptOS] Ollama binary already present, skipping download."
else
    echo "[promptOS] Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

# Restore our service file — the install script overwrites it
cat > /etc/systemd/system/ollama.service << 'EOF'
[Unit]
Description=Ollama AI Service
After=network.target

[Service]
Type=simple
User=root
Environment=OLLAMA_MODELS=/var/lib/ollama/models
Environment=OLLAMA_HOST=127.0.0.1:11434
Environment=OLLAMA_LOAD_TIMEOUT=10m
ExecStart=/usr/local/bin/ollama serve
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Set model storage path
OLLAMA_HOME=/var/lib/ollama
OLLAMA_MODELS=$OLLAMA_HOME/models
mkdir -p "$OLLAMA_MODELS"

# Check if model is already cached (copied from Docker volume by docker-build.sh)
MODEL_MANIFEST="$OLLAMA_MODELS/manifests/registry.ollama.ai/library/qwen2.5/3b"
if [ -f "$MODEL_MANIFEST" ]; then
    echo "[promptOS] Model qwen2.5:3b already cached, skipping pull."
else
    echo "[promptOS] Pulling base model (qwen2.5:3b)..."
    # Start the daemon temporarily, pull the model, then stop it
    OLLAMA_MODELS=$OLLAMA_MODELS OLLAMA_HOST=127.0.0.1:11434 ollama serve &
    OLLAMA_PID=$!

    # Wait for daemon to be ready
    for i in $(seq 1 30); do
        if curl -sf http://127.0.0.1:11434 >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    OLLAMA_MODELS=$OLLAMA_MODELS ollama pull qwen2.5:3b

    # Stop daemon cleanly
    kill "$OLLAMA_PID" 2>/dev/null || true
    wait "$OLLAMA_PID" 2>/dev/null || true
fi

echo "[promptOS] Ollama ready with model qwen2.5:3b"

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
