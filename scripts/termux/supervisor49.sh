#!/data/data/com.termux/files/usr/bin/bash
# supervisor49.sh - supervisor auto-curativo (conservador) de la sesion GNOME 49.
# Uso: supervisor49.sh [--observe]
#   --observe  registra muertes y forense pero NO relanza.
#   --stop     detiene el supervisor activo (por PID del pidfile).
# Arranque opt-in: gnome49 --supervised  o  SUBSTRATE_SUPERVISOR=1 gnome49
# Prohibido pkill -f: todo se mata por PID.
set -u
RT="$PREFIX/tmp/rt-dex"
PIDF="$RT/supervisor49.pid"
LOCK="$RT/supervisor49.lock"
LOG="$RT/supervisor.log"
OFF="$RT/supervisor.off"
MODE=act
case "${1:-}" in
  --observe) MODE=observe ;;
  --stop)
    p=$(cat "$PIDF" 2>/dev/null || true)
    if [ -n "${p:-}" ] && [ -d "/proc/$p" ]; then
      c=$(tr '\0' ' ' 2>/dev/null < "/proc/$p/cmdline" || true)
      case "$c" in *supervisor49.sh*) kill "$p" 2>/dev/null && echo "supervisor $p detenido"; exit 0 ;; esac
    fi
    echo "no hay supervisor activo"; exit 0 ;;
esac

# singleton real con flock (sin carreras de pidfile)
exec 9>"$LOCK"
if ! flock -n 9; then echo "supervisor ya activo (lock)"; exit 0; fi
echo $$ > "$PIDF"

log() { printf '%s %s\n' "$(date +%T)" "$*" >> "$LOG"; }
shell_pid()   { cat "$RT/shell49.pid" 2>/dev/null || true; }
shell_alive() { local p; p=$(shell_pid); [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }
forensic()    { bash "$RT/forensics-snapshot.sh" "$1" >/dev/null 2>&1 || true; }

x_ok() {
  proot-distro login ubuntu-gnome --shared-tmp -- \
    bash -c "DISPLAY=:0 timeout 15 xdpyinfo >/dev/null 2>&1"
}
wm_ok() {
  proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
    export DISPLAY=:0
    id=$(xprop -root -notype _NET_SUPPORTING_WM_CHECK 2>/dev/null | sed -n "s/.*# //p")
    [ -n "$id" ] || exit 1
    xprop -id "$id" -notype _NET_WM_NAME WM_NAME 2>/dev/null | grep -qi gnome' >/dev/null 2>&1
}

phantom_check() {
  local v
  v=$(timeout 10 adb -s 127.0.0.1:5555 shell settings get global settings_enable_monitor_phantom_procs 2>/dev/null | tr -d '\r')
  case "$v" in false) return 0 ;; esac
  log "phantom config revertida (monitor_phantom_procs=${v:-?}); re-aplicando"
  timeout 10 adb -s 127.0.0.1:5555 shell settings put global settings_enable_monitor_phantom_procs false >/dev/null 2>&1
  timeout 10 adb -s 127.0.0.1:5555 shell device_config put activity_manager max_phantom_processes 2147483647 >/dev/null 2>&1
}

recover() { # $1 = motivo
  log "FALLO confirmado: $1 (modo=$MODE intentos=$RETRIES)"
  forensic "DEATH"
  [ "$MODE" = observe ] && return 0
  RETRIES=$((RETRIES+1))
  case "$RETRIES" in 1) sleep 2 ;; 2) sleep 5 ;; *) sleep 10 ;; esac
  if [ "$RETRIES" -le 3 ]; then
    log "reintento $RETRIES/3"
    SUBSTRATE_NO_SUPERVISOR=1 bash "$PREFIX/bin/gnome49" --restart >> "$LOG" 2>&1
  else
    log "3 fallos consecutivos: MODO SOFTWARE"
    SUBSTRATE_NO_SUPERVISOR=1 GNOME49_SW=1 bash "$PREFIX/bin/gnome49" --restart >> "$LOG" 2>&1
    termux-notification --title "SubstrateOS / GNOME 49" \
      --content "3 fallos seguidos: activado modo software (llvmpipe)." 2>/dev/null || true
  fi
  LAST_RESTART=$(date +%s)
  XFAIL=0; WFAIL=0
}

[ -e "$OFF" ] && { rm -f "$OFF"; }
log "supervisor arrancado pid=$$ modo=$MODE (opt-in, conservador)"
RETRIES=0; LAST_RESTART=0; DEATH=0; XFAIL=0; WFAIL=0
LAST_PROBE=0; LAST_PHANTOM=0; ALIVE_SINCE=$(date +%s)

while :; do
  now=$(date +%s)

  # apagado limpio por fichero
  if [ -f "$OFF" ]; then log "kill-switch: saliendo"; rm -f "$OFF" "$PIDF"; exit 0; fi

  # 1) muerte = PID ausente en 2 muestras seguidas (>=4 s), nunca por una sonda
  if ! shell_alive; then
    DEATH=$((DEATH+1))
  else
    DEATH=0
    [ $((now-ALIVE_SINCE)) -ge 600 ] && { [ "$RETRIES" -ne 0 ] && log "sesion estable 10 min: reset contadores"; RETRIES=0; }
  fi

  if [ "$DEATH" -ge 2 ] && [ $((now-LAST_RESTART)) -ge 120 ]; then
    recover "shell ausente (${DEATH} muestras)"
    DEATH=0; ALIVE_SINCE=$(date +%s)
    continue
  fi

  # 2) sondas profundas: cada 60 s, solo con shell estable >180 s tras un reinicio,
  #    y requieren 3 fallos consecutivos (>=3 min) para actuar.
  if [ "$MODE" = act ] && shell_alive && [ $((now-LAST_RESTART)) -ge 180 ] \
     && [ $((now-LAST_PROBE)) -ge 60 ]; then
    LAST_PROBE=$now
    if x_ok; then XFAIL=0; else XFAIL=$((XFAIL+1)); fi
    if wm_ok; then WFAIL=0; else WFAIL=$((WFAIL+1)); fi
    if [ "$XFAIL" -ge 3 ]; then
      log "X caido 3 sondas seguidas: relanzando termux-x11"
      forensic "X-DEAD"
      nohup termux-x11 :0 >/dev/null 2>&1 &
      sleep 12
      SUBSTRATE_NO_SUPERVISOR=1 bash "$PREFIX/bin/gnome49" --restart >> "$LOG" 2>&1
      LAST_RESTART=$(date +%s); XFAIL=0; WFAIL=0
    elif [ "$WFAIL" -ge 3 ]; then
      log "sin WM 3 sondas seguidas: reiniciando UI"
      forensic "NO-WM"
      SUBSTRATE_NO_SUPERVISOR=1 bash "$PREFIX/bin/gnome49" --restart >> "$LOG" 2>&1
      LAST_RESTART=$(date +%s); XFAIL=0; WFAIL=0
    fi
  fi

  # 3) phantom config cada 10 min
  if [ "$MODE" = act ] && [ $((now-LAST_PHANTOM)) -ge 600 ]; then
    LAST_PHANTOM=$now; phantom_check
  fi

  sleep 2
done
