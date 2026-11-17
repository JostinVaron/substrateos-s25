#!/data/data/com.termux/files/usr/bin/bash
# supervisor49.sh - supervisor auto-curativo de la sesion GNOME 49 (Termux nativo).
# Uso: supervisor49.sh [--observe]
#   --observe  registra muertes y forense pero NO relanza (para series de medicion).
# Prohibido pkill -f: todo se mata por PID de pidfile.
set -u
RT="$PREFIX/tmp/rt-dex"
PIDF="$RT/supervisor49.pid"
LOG="$RT/supervisor.log"
MODE=act
case "${1:-}" in --observe) MODE=observe ;; esac

# singleton: si ya hay un supervisor vivo, no duplicar
old=$(cat "$PIDF" 2>/dev/null || true)
if [ -n "${old:-}" ] && [ -d "/proc/$old" ]; then
  c=$(tr '\0' ' ' 2>/dev/null < "/proc/$old/cmdline" || true)
  case "$c" in *supervisor49.sh*) echo "supervisor ya activo pid=$old"; exit 0 ;; esac
fi
echo $$ > "$PIDF"

log() { printf '%s %s\n' "$(date +%T)" "$*" >> "$LOG"; }
shell_pid()   { cat "$RT/shell49.pid" 2>/dev/null || true; }
shell_alive() { local p; p=$(shell_pid); [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }
forensic()    { bash "$RT/forensics-snapshot.sh" "$1" >/dev/null 2>&1 || true; }

x_ok() {
  proot-distro login ubuntu-gnome --shared-tmp -- \
    bash -c "DISPLAY=:0 timeout 4 xdpyinfo >/dev/null 2>&1"
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
  v=$(timeout 6 adb -s 127.0.0.1:5555 shell settings get global settings_enable_monitor_phantom_procs 2>/dev/null | tr -d '\r')
  if [ "$v" != "false" ]; then
    log "phantom config revertida (monitor_phantom_procs=${v:-?}); re-aplicando"
    timeout 8 adb -s 127.0.0.1:5555 shell settings put global settings_enable_monitor_phantom_procs false >/dev/null 2>&1
    timeout 8 adb -s 127.0.0.1:5555 shell device_config put activity_manager max_phantom_processes 2147483647 >/dev/null 2>&1
    timeout 8 adb -s 127.0.0.1:5555 shell am set-standby-bucket com.termux active >/dev/null 2>&1
    timeout 8 adb -s 127.0.0.1:5555 shell cmd appops set com.termux RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
  fi
}

recover() { # $1 = motivo
  log "FALLO: $1 (modo=$MODE intentos=$RETRIES)"
  forensic "DEATH"
  [ "$MODE" = observe ] && return 0
  RETRIES=$((RETRIES+1))
  case "$RETRIES" in
    1) sleep 2 ;;
    2) sleep 5 ;;
    3) sleep 10 ;;
  esac
  if [ "$RETRIES" -le 3 ]; then
    log "reintento $RETRIES/3"
    bash "$PREFIX/bin/gnome49" --restart >> "$LOG" 2>&1
  else
    log "3 fallos consecutivos: MODO SOFTWARE"
    GNOME49_SW=1 bash "$PREFIX/bin/gnome49" --restart >> "$LOG" 2>&1
    termux-notification --title "SubstrateOS / GNOME 49" \
      --content "3 fallos seguidos: activado modo software (llvmpipe)." 2>/dev/null || true
    SW=1
  fi
}

RETRIES=0; SW=0; SW_AT=0
alive_since=$(date +%s); last_x=0; last_wm=0; last_phantom=0; death_seen=0
log "supervisor arrancado pid=$$ modo=$MODE"

while :; do
  now=$(date +%s)
  if ! shell_alive; then
    if [ "$MODE" = observe ]; then
      if [ "$death_seen" = 0 ]; then
        death_seen=1
        log "shell ausente (observacion: registrada, sin accion)"
        forensic "OBSERVED"
      fi
      sleep 2
      continue
    fi
    death_seen=0
    recover "shell muerto/ausente"
    alive_since=$(date +%s)
  else
    death_seen=0
    if [ $((now-alive_since)) -ge 600 ] && [ "$RETRIES" -ne 0 ]; then
      log "sesion estable >=10 min: reset de contadores (antes $RETRIES)"
      RETRIES=0; SW=0
    fi
    if [ "$MODE" = act ] && [ $((now-last_wm)) -ge 10 ]; then
      last_wm=$now
      if ! x_ok; then
        log "X :0 no responde: relanzando termux-x11"
        nohup termux-x11 :0 >/dev/null 2>&1 &
        sleep 12
        bash "$PREFIX/bin/gnome49" --restart >> "$LOG" 2>&1
        alive_since=$(date +%s)
      elif ! wm_ok; then
        log "shell vivo pero sin WM/UI: reiniciando"
        forensic "NO-WM"
        bash "$PREFIX/bin/gnome49" --restart >> "$LOG" 2>&1
        alive_since=$(date +%s)
      fi
    fi
  fi
  if [ "$MODE" = act ] && [ $((now-last_phantom)) -ge 600 ]; then
    last_phantom=$now
    phantom_check
  fi
  sleep 2
done
