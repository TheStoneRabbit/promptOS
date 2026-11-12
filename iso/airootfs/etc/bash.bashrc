# promptOS — launch promptsh for any interactive shell session
# Skip if we're already inside promptsh, or if not interactive
if [[ $- == *i* ]] && [[ -z "$PROMPTSH_ACTIVE" ]] && [[ -x /usr/local/bin/promptsh ]]; then
    export PROMPTSH_ACTIVE=1
    # Deliberately not `exec`: if promptsh fails to start (e.g. a half-applied
    # update), fall back to this bash instead of closing the terminal/SSH session.
    # A clean exit from promptsh still ends the shell as before.
    if /usr/local/bin/promptsh; then
        exit
    fi
    echo "promptsh exited with an error — you're in plain bash. Run 'promptsh' to retry." >&2
fi
