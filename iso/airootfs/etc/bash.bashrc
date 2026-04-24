# promptOS — launch promptsh for any interactive shell session
# Skip if we're already inside promptsh, or if not interactive
if [[ $- == *i* ]] && [[ -z "$PROMPTSH_ACTIVE" ]] && [[ -x /usr/local/bin/promptsh ]]; then
    export PROMPTSH_ACTIVE=1
    exec /usr/local/bin/promptsh
fi
