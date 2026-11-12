# promptOS — auto-launch promptsh for interactive login shells (TTY, SSH).
# /etc/bash.bashrc handles non-login interactive shells (terminals inside a
# graphical desktop session). Together they cover both cases without breaking
# graphical session bootstrap, which uses non-interactive shells.
case "$-" in
    *i*)
        if [ -z "$PROMPTSH_ACTIVE" ] && [ -x /usr/local/bin/promptsh ] && [ -t 0 ]; then
            # On the local console, offer wifi setup if not already online.
            if [ "$(tty)" = "/dev/tty1" ] && [ -x /usr/local/bin/promptos-wifi ]; then
                /usr/local/bin/promptos-wifi --auto
            fi
            export PROMPTSH_ACTIVE=1
            # Not `exec`: a promptsh crash drops to bash instead of logging out.
            if /usr/local/bin/promptsh; then
                exit
            fi
            echo "promptsh exited with an error — you're in plain bash. Run 'promptsh' to retry." >&2
        fi
        ;;
esac
