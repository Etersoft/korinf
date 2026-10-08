#!/bin/sh
#
# Install the system files of korinf on the build host (builder64): the
# systemd units of the robot and buildapi, the /run/eterbuild tmpfiles entry
# and the sudoers rules of the builder group. Shows what differs first.
#
# Usage: robot/service/install.sh [-n]   (-n: only show the differences)
#
# The files are read by the calling user and written by root through stdin:
# root may not read the home directories (NFS root squash).

cd "$(dirname "$0")" || exit 1

DRYRUN=''
[ "$1" = "-n" ] && DRYRUN=1

UNITS="korinf-buildapi.service korinf-queuewatcher.service korinf-watchbuilder.service"
# <source>:<target>:<mode>
FILES="eterbuild.conf:/etc/tmpfiles.d/eterbuild.conf:644"
for u in $UNITS ; do
    FILES="$FILES $u:/etc/systemd/system/$u:644"
done

CHANGED=''
for f in $FILES ; do
    src=${f%%:*}
    rest=${f#*:}
    dst=${rest%%:*}
    if cmp -s "$src" "$dst" 2>/dev/null ; then
        echo "= $dst"
        continue
    fi
    echo "* $dst"
    diff -u "$dst" "$src" 2>/dev/null
    CHANGED="$CHANGED $f"
done
# sudoers.d is readable by root only
if sudo cmp -s sudoers.builder /etc/sudoers.d/builder ; then
    echo "= /etc/sudoers.d/builder"
else
    echo "* /etc/sudoers.d/builder"
    SUDOERS=1
fi

[ -n "$DRYRUN" ] && exit 0
[ -n "$CHANGED$SUDOERS" ] || { echo "Nothing to install" ; exit 0 ; }

for f in $CHANGED ; do
    src=${f%%:*}
    rest=${f#*:}
    sudo install -m "${rest#*:}" /dev/stdin "${rest%%:*}" < "$src" || exit 1
done
if [ -n "$SUDOERS" ] ; then
    # a broken sudoers file would lock sudo out: check it before it is used
    sudo visudo -c -q -f /dev/stdin < sudoers.builder || { echo "sudoers.builder is invalid" >&2 ; exit 1 ; }
    sudo install -m 440 /dev/stdin /etc/sudoers.d/builder < sudoers.builder || exit 1
fi
sudo systemd-tmpfiles --create /etc/tmpfiles.d/eterbuild.conf
sudo systemctl daemon-reload
for u in $UNITS ; do
    case "$CHANGED" in
        *"$u"*) sudo systemctl try-restart "$u" && echo "Restarted $u" ;;
    esac
done
