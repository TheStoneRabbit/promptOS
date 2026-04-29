#!/usr/bin/env bash
# push.sh — push promptOS airootfs changes to a running install over SSH.
# Skips per-machine state (config, keys, shadow, passwd) so user data is safe.
#
# Usage:
#   scripts/push.sh <host>              # default user is root
#   scripts/push.sh user@host           # specific user (will use sudo)
#   scripts/push.sh -n <host>           # dry-run (preview, no transfer)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIROOTFS="$REPO_ROOT/iso/airootfs"

DRY=""
if [ "${1:-}" = "-n" ] || [ "${1:-}" = "--dry-run" ]; then
    DRY="-n"
    shift
fi

if [ $# -lt 1 ]; then
    cat >&2 <<EOF
Usage: $0 [-n|--dry-run] [user@]<host>

Pushes promptsh, helper scripts, the provider library, and shell-launcher files
from this repo to a running promptOS install via SSH.

Does NOT touch: /etc/promptos/config, /etc/promptos/keys, /etc/shadow, /etc/passwd
(per-machine state stays intact).

Examples:
  $0 192.168.1.50
  $0 mason@192.168.1.50
  $0 -n root@promptos.local
EOF
    exit 1
fi

TARGET="$1"
if [[ "$TARGET" != *@* ]]; then
    TARGET="root@$TARGET"
fi

REMOTE_USER="${TARGET%@*}"
SUDO=""
if [ "$REMOTE_USER" != "root" ]; then
    SUDO="sudo "
fi

# Files / dirs to push (paths are relative to the system root; trailing / on
# directories means "contents of" rather than "directory itself").
FILES=(
    usr/local/bin/promptsh
    usr/local/bin/promptos-keys
    usr/local/bin/promptos-wifi
    usr/local/bin/promptos-model
    usr/local/bin/promptos-patch
    usr/local/bin/promptos-gui
    usr/local/bin/promptos-warmup
    usr/local/bin/promptos-install
    usr/local/bin/promptos-web
    usr/local/lib/promptos/
    etc/profile.d/promptsh.sh
    etc/bash.bashrc
    etc/ssh/sshd_config.d/promptos.conf
    etc/vconsole.conf
    etc/dconf/profile/
    etc/dconf/db/local.d/
    etc/dconf/db/gdm.d/
    usr/share/applications/org.promptos.ControlCenter.desktop
    usr/share/icons/hicolor/
    usr/share/pixmaps/
    usr/share/backgrounds/promptos/
    usr/share/promptos/
)

# Drop entries that don't exist locally (e.g. if you removed a script).
RSYNC_LIST=$(mktemp)
trap 'rm -f "$RSYNC_LIST"' EXIT
for f in "${FILES[@]}"; do
    if [ -e "$AIROOTFS/$f" ]; then
        echo "$f" >> "$RSYNC_LIST"
    else
        echo "  (skip) $f — not present locally" >&2
    fi
done

echo "==> Target: $TARGET"
[ -n "$DRY" ] && echo "==> DRY RUN (no files will be transferred)"

# Rsync. -R preserves the relative source paths so files land at the right
# spot on the target. --rsync-path uses sudo if we're not connecting as root.
rsync $DRY -avzR \
    --rsync-path="${SUDO}rsync" \
    --files-from="$RSYNC_LIST" \
    "$AIROOTFS/./" \
    "$TARGET:/"

if [ -n "$DRY" ]; then
    echo "==> Dry run complete."
    exit 0
fi

# Post-sync: fix perms and reload sshd if its config changed.
echo "==> Fixing perms + reloading sshd on remote..."
ssh "$TARGET" "${SUDO}bash -s" <<'REMOTE'
set -e
chmod 755 /usr/local/bin/promptsh \
          /usr/local/bin/promptos-keys \
          /usr/local/bin/promptos-wifi \
          /usr/local/bin/promptos-model \
          /usr/local/bin/promptos-patch \
          /usr/local/bin/promptos-gui \
          /usr/local/bin/promptos-warmup \
          /usr/local/bin/promptos-install 2>/dev/null || true
chmod 755 /etc/profile.d/promptsh.sh 2>/dev/null || true
# Recompile python bytecode for slightly faster cold start.
python -m compileall -q /usr/local/lib/promptos/ 2>/dev/null || true
# Reload sshd if its drop-in changed (idempotent — fine to run regardless).
systemctl reload sshd 2>/dev/null || true
# Recompile dconf system db so wallpaper / login-screen changes apply,
# then bounce gdm if it's installed so the login screen picks them up.
if command -v dconf >/dev/null 2>&1; then
    dconf update 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi
if systemctl is-enabled gdm.service >/dev/null 2>&1; then
    # Use try-restart so we don't kick a logged-in user unless gdm is already running.
    systemctl try-restart gdm.service 2>/dev/null || true
fi
REMOTE

echo "==> Done."
echo "    promptsh changes apply on next login (type 'exit' and reconnect)."
echo "    /etc/vconsole.conf changes apply on next boot, or run: setfont \$(awk -F= '/^FONT/{print \$2}' /etc/vconsole.conf)"
