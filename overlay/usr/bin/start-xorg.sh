#!/usr/bin/env bash
###
# File: start-xorg.sh
# Project: bin
# File Created: Tuesday, 11th January 2022 8:28:52 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 6th October 2022 9:21:00 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###
set -e
source /usr/bin/common-functions.sh

# CATCH TERM SIGNAL:
_term() {
    kill -TERM "$xorg_pid" 2>/dev/null
}
trap _term SIGTERM SIGINT


# EXECUTE PROCESS:
# Wait for udev
if [ $(grep autostart /etc/supervisor.d/udev.ini 2> /dev/null) == "autostart=true" ]; then
    wait_for_udev
fi
# Homelab: hardened restart hygiene. A transient X exit (e.g. Sunshine's
# NVENC/capture probe blipping the server) used to become permanent: the
# supervisor respawns Xorg instantly, the new server collides with the
# dying instance's still-held /tmp/.X<n> socket ("server already running"),
# fails, respawns, collides -> infinite loop. Kill any lingering Xorg on
# this display, wait for it to release the socket, THEN clean + start, so a
# blip self-recovers instead of looping.
_dn="${DISPLAY#:}"; _dn="${_dn%%.*}"
pkill -x Xorg 2>/dev/null || true
for _i in $(seq 1 25); do pgrep -x Xorg >/dev/null 2>&1 && sleep 0.2 || break; done
rm -f "/tmp/.X${_dn}-lock" "/tmp/.X11-unix/X${_dn}" 2>/dev/null || true
sleep 0.5
# Run X server
/usr/bin/Xorg \
    -ac \
    -noreset \
    -novtswitch \
    -sharevts \
    +extension RANDR \
    +extension RENDER \
    +extension GLX \
    +extension XVideo \
    +extension DOUBLE-BUFFER \
    +extension SECURITY \
    +extension DAMAGE \
    +extension X-Resource \
    -extension XINERAMA -xinerama \
    +extension Composite +extension COMPOSITE \
    -dpms \
    -s off \
    -nolisten tcp \
    -iglx \
    -verbose \
    vt7 "${DISPLAY:?}" &
xorg_pid=$!


# WAIT FOR CHILD PROCESS:
wait "$xorg_pid"
