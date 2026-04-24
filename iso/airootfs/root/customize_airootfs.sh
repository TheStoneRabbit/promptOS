#!/usr/bin/env bash
# customize_airootfs.sh — runs inside the chroot after pacstrap
# Used to install software that can't be added via packages.x86_64
set -euo pipefail

echo "[promptOS] Running airootfs customization..."

# ── Ollama ────────────────────────────────────────────────────────────────────
# Use cached binary from Docker volume if available, otherwise download
if [ -f /var/lib/ollama/bin/ollama ]; then
    echo "[promptOS] Using cached Ollama binary..."
    install -m755 /var/lib/ollama/bin/ollama /usr/local/bin/ollama
else
    echo "[promptOS] Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    # Cache the binary to the Docker volume for future builds
    mkdir -p /var/lib/ollama/bin
    cp /usr/local/bin/ollama /var/lib/ollama/bin/ollama
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
MODEL_MANIFEST="$OLLAMA_MODELS/manifests/registry.ollama.ai/library/dolphin3/8b"
if [ -f "$MODEL_MANIFEST" ]; then
    echo "[promptOS] Model dolphin3:8b already cached, skipping pull."
else
    echo "[promptOS] Pulling base model (dolphin3:8b)..."
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

    OLLAMA_MODELS=$OLLAMA_MODELS ollama pull dolphin3:8b

    # Stop daemon cleanly
    kill "$OLLAMA_PID" 2>/dev/null || true
    wait "$OLLAMA_PID" 2>/dev/null || true
fi

echo "[promptOS] Ollama ready with model dolphin3:8b"

# ── Pre-compile Python bytecode for faster startup ────────────────────────────
echo "[promptOS] Pre-compiling Python bytecode..."
python -m compileall -q /usr/local/lib/promptos/ 2>/dev/null || true

# ── Cleanup ───────────────────────────────────────────────────────────────────
echo "[promptOS] Airootfs customization complete."
