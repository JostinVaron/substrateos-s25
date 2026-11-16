#!/bin/bash
export DISPLAY=:0 HOME=/home/dexuser XDG_RUNTIME_DIR=/tmp/rt-dex
. /etc/profile.d/zz-adreno-gpu.sh 2>/dev/null
mkdir -p /tmp/rt-dex && chmod 700 /tmp/rt-dex
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/rt-dex/dbus-system
pkill -x gnome-shell 2>/dev/null; pkill -x weston 2>/dev/null; sleep 2
rm -f /tmp/rt-dex/dbus-system /tmp/rt-dex/wayland-moderno
nohup dbus-daemon --config-file=/tmp/rt-dex/dbus-system.conf >/tmp/rt-dex/dbus-system.log 2>&1 &
echo $! > /tmp/rt-dex/dbus-system.pid
sleep 3
nohup python3 /tmp/rt-dex/fake-login1.py >/tmp/rt-dex/login1.log 2>&1 &
echo $! > /tmp/rt-dex/login1.pid
sleep 4
nohup weston --backend=x11-backend.so --socket=wayland-moderno >/tmp/rt-dex/weston.log 2>&1 &
echo $! > /tmp/rt-dex/weston.pid
sleep 8
nohup dbus-run-session -- env WAYLAND_DISPLAY=wayland-moderno XDG_CURRENT_DESKTOP=GNOME XDG_SESSION_TYPE=wayland GDK_BACKEND=wayland XDG_SESSION_ID=s1 DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/rt-dex/dbus-system HOME=/home/dexuser XDG_RUNTIME_DIR=/tmp/rt-dex gnome-shell --wayland >/tmp/rt-dex/shell.log 2>&1 &
echo $! > /tmp/rt-dex/shell.pid
sleep 25
if pgrep -x gnome-shell >/dev/null; then echo "gnome-shell moderno vivo"; else echo "gnome-shell murio"; fi
