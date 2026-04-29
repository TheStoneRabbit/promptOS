#!/usr/bin/env bash
# update.sh — fetch promptOS sources and run local installer.
#
# Default behavior:
# - Downloads the promptOS repo snapshot from GitHub (default ref: main)
# - Executes scripts/install-local.sh from that snapshot
#
# Usage:
#   scripts/update.sh
#   scripts/update.sh --ref v1.2.3
#   scripts/update.sh --repo TheStoneRabbit/promptOS --ref main
#   scripts/update.sh --dry-run
#   scripts/update.sh --keep
set -euo pipefail

REPO="TheStoneRabbit/promptOS"
REF="main"
DRY_RUN=""
KEEP=""

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --repo <owner/name>   GitHub repo (default: ${REPO})
  --ref <tag|branch>    Git ref to fetch (default: ${REF})
  -n, --dry-run         Pass dry-run to install-local.sh
  --keep                Keep downloaded temp directory for inspection
  -h, --help            Show this help

Examples:
  $0
  $0 --ref v1.0.0
  $0 --repo TheStoneRabbit/promptOS --ref main
  $0 --dry-run
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --repo)
            REPO="${2:-}"; shift 2 ;;
        --ref)
            REF="${2:-}"; shift 2 ;;
        -n|--dry-run)
            DRY_RUN="--dry-run"; shift ;;
        --keep)
            KEEP="1"; shift ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required." >&2
    exit 1
fi
if ! command -v tar >/dev/null 2>&1; then
    echo "Error: tar is required." >&2
    exit 1
fi

URL="https://codeload.github.com/${REPO}/tar.gz/${REF}"
TMP_DIR="$(mktemp -d)"
ARCHIVE="${TMP_DIR}/promptos.tar.gz"
trap 'if [ -z "${KEEP}" ]; then rm -rf "${TMP_DIR}"; else echo "Kept: ${TMP_DIR}"; fi' EXIT

echo "==> Downloading promptOS from ${URL}"
curl -fL --retry 3 --connect-timeout 10 --max-time 300 "${URL}" -o "${ARCHIVE}"

echo "==> Extracting archive"
tar -xzf "${ARCHIVE}" -C "${TMP_DIR}"

SNAPSHOT_DIR="$(find "${TMP_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [ -z "${SNAPSHOT_DIR}" ] || [ ! -d "${SNAPSHOT_DIR}/scripts" ]; then
    echo "Error: invalid snapshot layout." >&2
    exit 1
fi

INSTALL_SCRIPT="${SNAPSHOT_DIR}/scripts/install-local.sh"
if [ ! -x "${INSTALL_SCRIPT}" ]; then
    chmod +x "${INSTALL_SCRIPT}" || true
fi
if [ ! -f "${INSTALL_SCRIPT}" ]; then
    echo "Error: install-local.sh not found in snapshot." >&2
    exit 1
fi

echo "==> Running local installer from snapshot"
if [ -n "${DRY_RUN}" ]; then
    "${INSTALL_SCRIPT}" --dry-run
else
    "${INSTALL_SCRIPT}"
fi

echo "==> Update complete (${REPO}@${REF})"
