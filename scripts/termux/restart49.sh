#!/data/data/com.termux/files/usr/bin/bash
# restart49.sh - reinicia la sesion GNOME 49 X11 de forma segura.
# Uso: restart49.sh [terminal|files|editor|calc ...]
# Corre en Termux nativo. NO toca el servidor X.
# PATCH-A67: tambien mata restos de sesiones Flashback genericas (metacity,
# gnome-panel, plank, gnome-flashback, arranque-escritorio) que sobrevivian al
# reinicio y tapaban el escritorio Tahoe.
set -u

RT="$PREFIX/tmp/rt-dex"
DISP=":0"
say() { printf '%s\n' "$*"; }
mkdir -p "$RT"

# --- 0) X debe estar vivo ---
if ! proot-distro login ubuntu-gnome --shared-tmp -- \
     bash -c "DISPLAY=$DISP timeout 4 xdpyinfo >/dev/null 2>&1"; then
  say "[S] X no responde en $DISP. Abre Termux:X11 y ejecuta: gnome49"
  exit 1
fi

# --- 1) parar sesion anterior y restos ---
say "[S] Deteniendo sesion anterior..."
bash "$PREFIX/bin/gnome49-stop" >/dev/null 2>&1 || true

# proots de la sesion (cmdline con ubuntu-gnome + session49.sh)
for p in $(ps -eo pid=,comm= 2>/dev/null | awk '$2=="proot"{print $1}'); do
  cmd=$(tr '\0' ' ' 2>/dev/null < "/proc/$p/cmdline") || continue
  case "$cmd" in
    *ubuntu-gnome*session49.sh*)
      kill -9 "$p" 2>/dev/null && say "[S] proot de sesion detenido ($p)" ;;
  esac
done

# restos con patrones anclados (apps, helpers y sesiones genericas)
for q in /proc/[0-9]*; do
  p=${q#/proc/}
  [ "$p" = "$$" ] && continue
  cmd=$(tr '\0' ' ' 2>/dev/null < "$q/cmdline") || continue
  case "$cmd" in
    gnome-terminal*|/usr/bin/gnome-terminal*|\
    gnome-calculator*|/usr/bin/gnome-calculator*|\
    gnome-text-editor*|nautilus*|/usr/bin/nautilus*|\
    *org.gnome.NautilusPreviewer*|*ding.js*|mutter-x11-frames*|\
    nm-stub.py*|python3\ /usr/local/share/substrate/nm-stub.py*|\
    bash\ /tmp/rt-dex/session-inner.sh*|bash\ /tmp/rt-dex/warmup49.sh*|\
    metacity*|/usr/bin/metacity*|\
    gnome-panel*|/usr/bin/gnome-panel*|/usr/libexec/gnome-panel*|\
    plank*|/usr/bin/plank*|\
    *gnome-flashback*|\
    *arranque-escritorio*)
      kill -9 "$p" 2>/dev/null && say "[S] resto detenido ($p)"
      ;;
    *ubuntu-gnome*pipewire*|*ubuntu-gnome*wireplumber*|*exec\ pipewire*|*exec\ wireplumber*)
      kill -9 "$p" 2>/dev/null && say "[S] proot de audio detenido ($p)"
      ;;
  esac
done
sleep 1

# --- 2) estado limpio ---
rm -f "$RT/shell49.pid" "$RT/session-bus.addr" "$RT/bus" \
      "$RT/login1.pid" "$RT/nm-stub.pid" "$RT/polkitd-helper.pid" \
      "$RT/system-bus49" "$RT/system-bus49.pid" \
      "$RT/gnome-shell-disable-extensions" 2>/dev/null || true
rm -f "$RT"/gsd-*.pid "$RT"/upowerd.pid "$RT"/colord.pid "$RT"/geoclue.pid \
      "$RT"/ppd.pid "$RT"/session-launch.pid 2>/dev/null || true
: > "$RT/session49-launch.log"

# --- 3) helper polkitd (espera al bus; sobrevive a reinicios del bus) ---
setsid nohup proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  while [ ! -S /tmp/rt-dex/system-bus49 ]; do sleep 1; done
  export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/rt-dex/system-bus49
  while :; do
    /usr/lib/polkit-1/polkitd --no-debug >>/tmp/rt-dex/polkitd.log 2>&1
    echo "polkitd exit=$? $(date -u +%FT%TZ)" >>/tmp/rt-dex/polkitd.log
    sleep 2
  done
' >>"$RT/polkitd-sup.log" 2>&1 </dev/null &
echo $! > "$RT/polkitd-helper.pid"

# --- 4) arrancar sesion ---
say "[S] Arrancando GNOME Shell 49 X11 (~35 s)..."
setsid nohup proot-distro login ubuntu-gnome --shared-tmp -- \
  bash /tmp/rt-dex/session49.sh >> "$RT/session49-launch.log" 2>&1 </dev/null &
echo $! > "$RT/session-launch.pid"

P=""
for _ in $(seq 1 50); do
  P=$(cat "$RT/shell49.pid" 2>/dev/null || true)
  [ -n "$P" ] && [ -d "/proc/$P" ] && break
  P=""
  sleep 1
done

if [ -z "$P" ]; then
  say "[S] ERROR: gnome-shell no arranco. Ultimas lineas:"
  tail -15 "$RT/session49-launch.log" 2>/dev/null
  tail -10 "$RT/shell49.log" 2>/dev/null
  exit 1
fi

taskset -apc 6-7 "$P" >/dev/null 2>&1 && say "[S] afinidad prime cores 6-7 aplicada"

# --- 5) apps opcionales ---
for app in "$@"; do
  case "$app" in
    terminal|gnome-terminal) cmd=gnome-terminal ;;
    files|nautilus)          cmd=nautilus ;;
    editor|text-editor)      cmd=gnome-text-editor ;;
    calc|calculator)         cmd=gnome-calculator ;;
    *) say "[S] app desconocida: $app"; continue ;;
  esac
  setsid nohup proot-distro login ubuntu-gnome --shared-tmp -- bash -c "
    export DISPLAY=:0 HOME=/home/dexuser XDG_RUNTIME_DIR=/tmp/rt-dex
    export XDG_CURRENT_DESKTOP=ubuntu:GNOME XDG_SESSION_TYPE=x11
    export DBUS_SESSION_BUS_ADDRESS=\$(cat /tmp/rt-dex/session-bus.addr)
    exec $cmd" >/dev/null 2>&1 < /dev/null &
done

# --- 6) estado ---
kg=$(ls -l "/proc/$P/fd" 2>/dev/null | grep -c kgsl)
sw=$(grep -cE 'swrast|llvmpipe' "/proc/$P/maps" 2>/dev/null || true)
dbusn=$(for q in /proc/[0-9]*; do c=$(tr '\0' ' ' 2>/dev/null < "$q/cmdline"); case "$c" in dbus-daemon*) echo x;; esac; done | wc -l)
say "[S] OK: shell pid=$P kgsl_fds=$kg swrast=$sw dbus=$dbusn"