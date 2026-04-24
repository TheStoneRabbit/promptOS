# promptOS root profile
# Auto-launch promptsh on TTY1 login

export PROMPTOS_MODEL="${PROMPTOS_MODEL:-llama3.2}"

if [ "$(tty)" = "/dev/tty1" ]; then
    exec /usr/local/bin/promptsh
fi
