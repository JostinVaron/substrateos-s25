#!/bin/bash
# SubstrateOS — volver al escritorio clasico (flashback)
export HOME=/home/dexuser
export XDG_RUNTIME_DIR=/tmp/rt-dex
[ -f /etc/profile.d/zz-adreno-gpu.sh ] && . /etc/profile.d/zz-adreno-gpu.sh
pkill -x gnome-shell 2>/dev/null; pkill -x weston 2>/dev/null
sleep 2
su -s /bin/bash dexuser -c "DISPLAY= XDG_RUNTIME_DIR=/tmp/rt-dex metacity --replace >/dev/null 2>&1 &"
sleep 2
su -s /bin/bash dexuser -c "DISPLAY= XDG_RUNTIME_DIR=/tmp/rt-dex metacity >/dev/null 2>&1 & gnome-panel >/dev/null 2>&1 & plank >/dev/null 2>&1 &"
exit 0
