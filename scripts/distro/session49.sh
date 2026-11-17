#!/bin/bash
# session49.sh - GNOME Shell 49 X11 sobre Ubuntu 26.04 en proot.
# Corre DENTRO del proot (proot-distro login ubuntu-gnome --shared-tmp).
# Reconstruido 15-nov-2026 tras la limpieza de /tmp (contenido recuperado del log).
set -u

RT=/tmp/rt-dex
mkdir -p "$RT"

# --- entorno de sesion ---
export HOME=/home/dexuser
export USER=dexuser
export LOGNAME=dexuser
export DISPLAY=:0
export XDG_RUNTIME_DIR="$RT"
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=ubuntu
export XDG_SESSION_ID=substrate
export DESKTOP_SESSION=ubuntu
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_DATA_DIRS=/usr/local/share:/usr/share:/var/lib/snapd/desktop
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export NO_AT_BRIDGE=1
# GTK4 en este proot/Adreno: si una app usa GSK GL o levanta at-spi al
# mapear su primera ventana, gnome-shell recibe SIGKILL (Android/GPU).
# Cairo + a11y off mantiene el shell vivo; el compositor sigue con freedreno.
export GSK_RENDERER=cairo
export GTK_A11Y=none
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export RT_SYSTEM_BUS=/tmp/rt-dex/system-bus49

# Receta GPU Adreno v4: Zink sobre Turnip/kgsl (Adreno 830).
# Escape hatch: GNOME49_SW=1 -> perfil software estable (llvmpipe/swrast).
if [ "${GNOME49_SW:-0}" = "1" ] && [ -f "$RT/zz-adreno-gpu.software.sh" ]; then
  . "$RT/zz-adreno-gpu.software.sh"
else
  . /etc/profile.d/zz-adreno-gpu.sh 2>/dev/null || true
fi
unset FD_MESA_DEBUG FD_FORCE_KGSL COGL_DISABLE_TFP
[ "${GNOME49_SW:-0}" = "1" ] || unset LIBGL_DRI3_DISABLE
export MESA_VK_WSI_PRESENT_MODE=immediate
export vblank_mode=0

ulimit -n 32768 2>/dev/null || true

export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$RT/system-bus49"

# --- bus de sistema dedicado ---
if [ ! -f "$RT/system-dbus49.conf" ]; then
  cat > "$RT/system-dbus49.conf" <<'EOF_DBUS'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>system</type>
  <listen>unix:path=/tmp/rt-dex/system-bus49</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow user="*"/>
    <allow own="*"/>
    <allow send_type="method_call"/>
    <allow send_type="signal"/>
    <allow send_type="method_return"/>
    <allow send_type="error"/>
    <allow receive_type="method_call"/>
    <allow receive_type="signal"/>
    <allow receive_type="method_return"/>
    <allow receive_type="error"/>
  </policy>
</busconfig>
EOF_DBUS
fi

if [ ! -S "$RT/system-bus49" ]; then
  dbus-daemon --config-file="$RT/system-dbus49.conf" --fork
fi
for _ in $(seq 1 10); do [ -S "$RT/system-bus49" ] && break; sleep 0.5; done

# --- stubs: login1 y NetworkManager ---
setsid nohup python3 /usr/local/share/substrate/fake-login1.py >>"$RT/login1.log" 2>&1 </dev/null &
echo $! > "$RT/login1.pid"
sleep 1
timeout 5 dbus-send --system --print-reply --dest=org.freedesktop.login1 \
  /org/freedesktop/login1 org.freedesktop.login1.Manager.CanSuspend >/dev/null 2>&1 \
  || echo "WARN: probe login1 fallo"

setsid nohup python3 /usr/local/share/substrate/nm-stub.py >>"$RT/nm-stub.log" 2>&1 </dev/null &
echo $! > "$RT/nm-stub.pid"
sleep 1

# --- servicios de sistema ---
# upower: stub propio con la bateria real del telefono (termux-battery-status).
# El upowerd real solo ve /sys falso bajo proot -> 0% y battery-missing.
if [ -f /usr/local/share/substrate/upower-stub.py ]; then
  setsid nohup python3 /usr/local/share/substrate/upower-stub.py >>"$RT/upowerd.log" 2>&1 </dev/null &
  echo $! > "$RT/upowerd.pid"
elif [ -x /usr/libexec/upowerd ]; then
  setsid nohup /usr/libexec/upowerd >>"$RT/upowerd.log" 2>&1 </dev/null &
  echo $! > "$RT/upowerd.pid"
fi
for d in colord geoclue; do
  if [ -x "/usr/libexec/$d" ]; then
    setsid nohup "/usr/libexec/$d" >>"$RT/$d.log" 2>&1 </dev/null &
    echo $! > "$RT/$d.pid"
  fi
done

# power-profiles-daemon: habilita Power Mode en Quick Settings
if [ -x /usr/libexec/power-profiles-daemon ]; then
  setsid nohup /usr/libexec/power-profiles-daemon >>"$RT/ppd.log" 2>&1 </dev/null &
  echo $! > "$RT/ppd.pid"
fi
sleep 1

# --- sesion (bus de usuario, gsd, portales, shell, warmup) ---
exec dbus-run-session -- bash /tmp/rt-dex/session-inner.sh
