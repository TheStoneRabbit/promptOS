#!/usr/bin/env bash
# build.sh — build the promptOS ISO using Docker (run this on macOS)
#
# Optionally bake an AI provider API key into the ISO so the booted system is
# ready to use with no on-device key entry:
#
#   ./scripts/build.sh --openai-key sk-proj-...
#   ./scripts/build.sh --claude-key sk-ant-...   --provider claude
#   ./scripts/build.sh --groq-key   gsk_...
#   PROMPTOS_OPENAI_KEY=sk-... ./scripts/build.sh        # via env instead
#
# Keys are injected inside the build container at run time — they are NOT
# written to the repo working tree or baked into Docker image layers. The
# resulting ISO does contain the key (that's the point), so treat that ISO as
# a secret.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
IMAGE_NAME="promptos-builder"

OPENAI_KEY="${PROMPTOS_OPENAI_KEY:-}"
CLAUDE_KEY="${PROMPTOS_CLAUDE_KEY:-}"
GROQ_KEY="${PROMPTOS_GROQ_KEY:-}"
PROVIDER="${PROMPTOS_PROVIDER:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --openai-key) OPENAI_KEY="$2"; shift 2 ;;
        --claude-key) CLAUDE_KEY="$2"; shift 2 ;;
        --groq-key)   GROQ_KEY="$2";   shift 2 ;;
        --provider)   PROVIDER="$2";   shift 2 ;;
        -h|--help)    sed -n '2,18p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Build the list of env vars to hand the container (only the ones provided).
DOCKER_ENV=()
[ -n "$OPENAI_KEY" ] && DOCKER_ENV+=(-e "PROMPTOS_BUILD_OPENAI_KEY=$OPENAI_KEY")
[ -n "$CLAUDE_KEY" ] && DOCKER_ENV+=(-e "PROMPTOS_BUILD_CLAUDE_KEY=$CLAUDE_KEY")
[ -n "$GROQ_KEY" ]   && DOCKER_ENV+=(-e "PROMPTOS_BUILD_GROQ_KEY=$GROQ_KEY")
[ -n "$PROVIDER" ]   && DOCKER_ENV+=(-e "PROMPTOS_BUILD_PROVIDER=$PROVIDER")
if [ "${#DOCKER_ENV[@]}" -gt 0 ]; then
    echo "==> Baking provider config into ISO (key material passed to container only)"
fi

echo "==> Building Docker image..."
docker build --no-cache -t "$IMAGE_NAME" -f "$REPO_ROOT/Dockerfile.build" "$REPO_ROOT"

echo "==> Running ISO build inside container..."
mkdir -p "$DIST_DIR"
# Mount ollama-cache volume to avoid re-downloading the model on every rebuild
docker run --rm \
    --privileged \
    ${DOCKER_ENV[@]+"${DOCKER_ENV[@]}"} \
    -v "$DIST_DIR":/output \
    -v promptos-ollama-cache:/var/lib/ollama \
    "$IMAGE_NAME"

echo ""
echo "==> Done! ISO is in $DIST_DIR/"
ls -lh "$DIST_DIR"/*.iso 2>/dev/null || echo "No ISO found — check build output above for errors."
