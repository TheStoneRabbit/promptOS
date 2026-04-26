# promptOS root profile
# Auto-launch promptsh on TTY1 login

export PROMPTOS_MODEL="${PROMPTOS_MODEL:-llama3.2}"

if [ "$(tty)" = "/dev/tty1" ]; then
    # Offer wifi setup if not already online (no-op when ethernet/saved network is up).
    [ -x /usr/local/bin/promptos-wifi ] && /usr/local/bin/promptos-wifi --auto
    exec /usr/local/bin/promptsh
fi
