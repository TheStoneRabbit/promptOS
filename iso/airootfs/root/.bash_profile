# promptOS root profile.
# The promptsh launcher lives in /etc/profile.d/promptsh.sh, which is sourced
# by every login bash and handles tty/ssh sessions for all users (root + admin).
[ -r /etc/profile ] && . /etc/profile
