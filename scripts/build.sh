#!/usr/bin/env bash
# build.sh — build the promptOS ISO using Docker (run this on macOS)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
IMAGE_NAME="promptos-builder"

echo "==> Building Docker image..."
docker build -t "$IMAGE_NAME" -f "$REPO_ROOT/Dockerfile.build" "$REPO_ROOT"

echo "==> Running ISO build inside container..."
mkdir -p "$DIST_DIR"
# Mount ollama-cache volume to avoid re-downloading the model on every rebuild
docker run --rm \
    --privileged \
    -v "$DIST_DIR":/output \
    -v promptos-ollama-cache:/var/lib/ollama \
    "$IMAGE_NAME"

echo ""
echo "==> Done! ISO is in $DIST_DIR/"
ls -lh "$DIST_DIR"/*.iso 2>/dev/null || echo "No ISO found — check build output above for errors."
