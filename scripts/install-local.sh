#!/usr/bin/env bash
# install-local.sh — install promptOS airootfs changes onto this machine.
# Mirrors scripts/push.sh behavior but performs a local sync to /.
#
# Usage:
#   scripts/install-local.sh              # install locally (uses sudo if needed)
#   scripts/install-local.sh -n           # dry-run (preview only)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIROOTFS="$REPO_ROOT/iso/airootfs"

DRY=""
if [ "${1:-}" = "-n" ] || [ "${1:-}" = "--dry-run" ]; then
    DRY="-n"
    shift
fi

if [ $# -gt 0 ]; then
    cat >&2 <<EOF
Usage: $0 [-n|--dry-run]

Installs promptsh, helper scripts, provider library, and shell-launcher files
from this repo to the local system root.

Does NOT touch: /etc/promptos/config, /etc/promptos/keys, /etc/shadow, /etc/passwd
(per-machine state stays intact).
EOF
    exit 1
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo "
fi

# Files / dirs to install (paths are relative to the system root; trailing /
# on directories means "contents of" rather than "directory itself").
FILES=(
    usr/local/bin/promptsh
    usr/local/bin/promptos-keys
    usr/local/bin/promptos-wifi
    usr/local/bin/promptos-model
    usr/local/bin/promptos-gui
    usr/local/bin/promptos-warmup
    usr/local/bin/promptos-install
    usr/local/bin/promptos-web
    usr/local/bin/promptos-firstboot
    usr/local/bin/promptos-wallpaper
    usr/local/lib/promptos/
    etc/profile.d/promptsh.sh
    etc/profile.d/00-promptos-x.sh
    etc/bash.bashrc
    root/.xinitrc
    etc/xdg/openbox/
    etc/promptos/picom.conf
    etc/promptos/tint2rc
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

RSYNC_LIST="$(mktemp)"
trap 'rm -f "$RSYNC_LIST"' EXIT
for f in "${FILES[@]}"; do
    if [ -e "$AIROOTFS/$f" ]; then
        echo "$f" >> "$RSYNC_LIST"
    else
        echo "  (skip) $f — not present locally" >&2
    fi
done

echo "==> Target: local machine (/)"
[ -n "$DRY" ] && echo "==> DRY RUN (no files will be copied)"

# Rsync locally. -R preserves relative source paths so files land correctly.
${SUDO}rsync $DRY -avR \
    --files-from="$RSYNC_LIST" \
    "$AIROOTFS/./" \
    /

if [ -n "$DRY" ]; then
    echo "==> Dry run complete."
    exit 0
fi

echo "==> Fixing perms + reloading services..."
${SUDO}bash -s <<'LOCAL'
set -e
chmod 755 /usr/local/bin/promptsh \
          /usr/local/bin/promptos-keys \
          /usr/local/bin/promptos-wifi \
          /usr/local/bin/promptos-model \
          /usr/local/bin/promptos-gui \
          /usr/local/bin/promptos-warmup \
          /usr/local/bin/promptos-firstboot \
          /usr/local/bin/promptos-wallpaper \
          /usr/local/bin/promptos-install 2>/dev/null || true
chmod 755 /etc/profile.d/promptsh.sh /root/.xinitrc \
          /etc/xdg/openbox/autostart 2>/dev/null || true
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
LOCAL

echo "==> Done."
echo "    promptsh changes apply on next login (type 'exit' and reconnect)."
echo "    /etc/vconsole.conf changes apply on next boot, or run: setfont \$(awk -F= '/^FONT/{print \$2}' /etc/vconsole.conf)"
