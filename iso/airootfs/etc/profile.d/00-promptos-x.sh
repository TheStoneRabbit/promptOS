# promptOS — start the graphical search-bar desktop on the local console.
#
# Runs before 'promptsh.sh' (lexical order) so the graphical session owns tty1.
# If X is disabled, unavailable, or exits, this falls through and the normal
# promptsh text shell takes over — preserving the escape hatch on every path.
#
# SSH and other TTYs are untouched: they never match /dev/tty1 and go straight
# to promptsh.

case "$-" in
    *i*)
        if [ -z "$PROMPTSH_ACTIVE" ] && [ -z "$DISPLAY" ] \
           && [ "$(tty)" = "/dev/tty1" ] && command -v startx >/dev/null 2>&1; then
            # Opt-out: set PROMPTOS_BOOT_GUI=0 in /etc/promptos/config.
            if ! grep -qs '^[[:space:]]*PROMPTOS_BOOT_GUI=0' /etc/promptos/config; then
                # One-time onboarding: WiFi connect + AI provider/API key.
                # (Also brings networking up, replacing the bare wifi --auto.)
                if [ -x /usr/local/bin/promptos-firstboot ]; then
                    /usr/local/bin/promptos-firstboot
                elif [ -x /usr/local/bin/promptos-wifi ]; then
                    /usr/local/bin/promptos-wifi --auto
                fi
                mkdir -p /var/log/promptos
                startx >/var/log/promptos/xorg.log 2>&1
                # X session ended — fall through to promptsh below.
            fi
        fi
        ;;
esac
