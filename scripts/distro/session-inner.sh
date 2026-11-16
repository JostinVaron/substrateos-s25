#!/bin/bash
# session-inner.sh - parte de la sesion que vive en el bus de usuario.
set -u

RT=/tmp/rt-dex
export HOME=/home/dexuser
export USER=dexuser
export DISPLAY=:0
export XDG_RUNTIME_DIR="$RT"
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=ubuntu
export XDG_SESSION_ID=substrate
export DESKTOP_SESSION=ubuntu
export GNOME_SHELL_SESSION_MODE=ubuntu
# Apps GTK4: Cairo evita el fallo de GPU al mapear; a11y off evita que
# at-spi tumbe el shell bajo este proot. El compositor no usa GSK.
export GSK_RENDERER=cairo
export GTK_A11Y=none
export NO_AT_BRIDGE=1

# direccion del bus de usuario + symlink estable $XDG_RUNTIME_DIR/bus
echo "$DBUS_SESSION_BUS_ADDRESS" > "$RT/session-bus.addr"
_bus_path=${DBUS_SESSION_BUS_ADDRESS#unix:path=}
_bus_path=${_bus_path%%,*}
[ -n "$_bus_path" ] && ln -sf "$_bus_path" "$RT/bus"

# Mantener el tema MacTahoe tambien en apps lanzadas por el shell/dock.
gsettings set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark" 2>/dev/null || true
gsettings set org.gnome.desktop.wm.preferences theme "MacTahoe-Dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme "MacTahoe-dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
# Mantener el wallpaper MacTahoe de dia que usan las capturas de referencia.
gsettings set org.gnome.desktop.background picture-uri "file:///home/dexuser/.local/share/backgrounds/MacTahoe-day.jpeg" 2>/dev/null || true
gsettings set org.gnome.desktop.background picture-uri-dark "file:///home/dexuser/.local/share/backgrounds/MacTahoe-day.jpeg" 2>/dev/null || true

# llavero (secrets) para apps que lo piden
( printf '\n' | gnome-keyring-daemon --start --components=secrets ) >>"$RT/keyring.log" 2>&1 || true

# audio: PipeWire entra en bucle bajo proot (ENOSYS, ~90% CPU). Desactivado por defecto.
# Para probar audio: RT_ENABLE_AUDIO=1 gnome49 --restart
if [ "${RT_ENABLE_AUDIO:-0}" = "1" ] && command -v pipewire >/dev/null 2>&1; then
  export PULSE_SERVER="unix:$RT/pulse/native"
  setsid nohup pipewire >>"$RT/pipewire.log" 2>&1 </dev/null &
  echo $! > "$RT/pipewire.pid"
  sleep 1
  if command -v pipewire-pulse >/dev/null 2>&1; then
    setsid nohup pipewire-pulse >>"$RT/pipewire-pulse.log" 2>&1 </dev/null &
    echo $! > "$RT/pipewire-pulse.pid"
  fi
  if command -v wireplumber >/dev/null 2>&1; then
    setsid nohup wireplumber >>"$RT/wireplumber.log" 2>&1 </dev/null &
    echo $! > "$RT/wireplumber.pid"
  fi
  sleep 1
fi

# gnome-settings-daemon: indicadores de la barra superior y quick settings
for s in power media-keys keyboard xsettings sound housekeeping a11y-settings screensaver-proxy color datetime rfkill; do
  setsid nohup "/usr/libexec/gsd-$s" >>"$RT/gsd-$s.log" 2>&1 </dev/null &
  echo $! > "$RT/gsd-$s.pid"
done

# portales pre-arrancados (evita pagar su activacion en cada app)
nohup /usr/libexec/xdg-desktop-portal >>"$RT/portal.log" 2>&1 &
nohup /usr/libexec/xdg-desktop-portal-gtk >>"$RT/portal-gtk.log" 2>&1 &
sleep 1

# Arranque limpio: sin DING (intenta lanzar Nautilus como root y falla con
# status 95) ni snapd-prompting (le falta su script auxiliar). Conservamos
# dock, appindicators, tiling-assistant y user-theme.
_cur=$(gsettings get org.gnome.shell disabled-extensions 2>/dev/null || echo "@as []")
_cur=${_cur#@as }
if [ "$_cur" = "[]" ] || [ -z "$_cur" ]; then
  _new="['ding@rastersoft.com', 'snapd-prompting@canonical.com']"
else
  _new="${_cur%]}, 'ding@rastersoft.com', 'snapd-prompting@canonical.com']"
fi
gsettings set org.gnome.shell disabled-extensions "$_new" 2>/dev/null \
  || echo "WARN: no se pudo desactivar DING" >>"$RT/shell49.log"

# Un marker viejo de "extensions disabled" impide cargar dock/tema.
rm -f "$RT/gnome-shell-disable-extensions"

# GNOME Shell X11. El wrapper registra el codigo de salida/signal para saber
# si el shell muere por si solo (137 = SIGKILL, 139 = SIGSEGV, etc.).
(
  trap '' HUP
  # Compositor estable: el compositor usa llvmpipe; las apps pueden usar
  # freedreno/kgsl por separado (ver /etc/profile.d/zz-adreno-gpu.sh).
  export LIBGL_ALWAYS_SOFTWARE=1
  export GALLIUM_DRIVER=llvmpipe
  export MESA_LOADER_DRIVER_OVERRIDE=swrast
  export LIBGL_DRI3_DISABLE=1
  gnome-shell >"$RT/shell49.log" 2>&1 &
  spid=$!
  echo "$spid" > "$RT/shell49.pid"
  wait "$spid"
  rc=$?
  {
    echo ""
    echo "SHELL_EXIT=$rc at $(date -u +%FT%TZ)"
  } >>"$RT/shell49.log"
) &

# Sin warmup: el arranque debe quedar limpio, sin ventanas de prueba.
# warmup49.sh se conserva solo para pruebas manuales (RT_ENABLE_WARMUP=1).

wait
