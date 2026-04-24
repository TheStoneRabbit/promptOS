#!/usr/bin/env bash
# customize_airootfs.sh — runs inside the chroot after pacstrap
# Used to install software that can't be added via packages.x86_64
set -euo pipefail

echo "[promptOS] Running airootfs customization..."

# ── Ollama ────────────────────────────────────────────────────────────────────
echo "[promptOS] Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

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

echo "[promptOS] Pulling base model (llama3.2:1b)..."
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

OLLAMA_MODELS=$OLLAMA_MODELS ollama pull llama3.2:1b

# Stop daemon cleanly
kill "$OLLAMA_PID" 2>/dev/null || true
wait "$OLLAMA_PID" 2>/dev/null || true

echo "[promptOS] Ollama installed with model llama3.2:1b"

# ── Cleanup ───────────────────────────────────────────────────────────────────
echo "[promptOS] Airootfs customization complete."
