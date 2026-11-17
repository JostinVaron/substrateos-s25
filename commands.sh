echo "=== MISION-A59-BLINDAJE-APPS — bajar oom_score_adj al lanzar cada app $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/a59.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. test de permiso: podemos escribir oom_score_adj dentro del proot? ---"
echo 0 > /proc/self/oom_score_adj 2>/dev/null && echo "escritura_directa_OK adj=$(cat /proc/self/oom_score_adj)" || echo "escritura_denegada"
echo "--- 2. wrapper de apps v2: blindaje automatico ---"
cat > /usr/local/bin/artcraft-app-launch <<'EOF'
#!/bin/bash
# Wrapper de apps con blindaje anti-LMKD: baja oom_score_adj del arbol al lanzar.
TS=$(date -u +%Y%m%dT%H%M%SZ)
LOG=/tmp/app-session-$TS.log
echo "[$(date -u +%FT%TZ)] app=$1 pid_inicio (blindaje v2)" > "$LOG"
( while true; do sleep 3; echo "[$(date -u +%FT%TZ)] rss_kb=$(ps -o rss= -p $PPID 2>/dev/null | tr -d ' ') adj=$(cat /proc/$PPID/oom_score_adj 2>/dev/null)" >> "$LOG"; done ) &
SAMP=$!
substrate-gpu-run "$@" >> "$LOG" 2>&1 &
APP=$!
# blindar al arbol inmediatamente tras el spawn (el truco: hacerlo rapido, antes de que LMKD mire)
for i in 1 2 3; do
  for P in $APP $(pgrep -P $APP 2>/dev/null) $(pgrep -x "$(basename "$1")" 2>/dev/null); do
    [ -n "$P" ] && echo 0 > /proc/$P/oom_score_adj 2>/dev/null
  done
  sleep 0.3
done
wait $APP
RC=$?
kill $SAMP 2>/dev/null
echo "[$(date -u +%FT%TZ)] EXIT_CODE=$RC adj_final=$(cat /proc/$APP/oom_score_adj 2>/dev/null)" >> "$LOG"
exit $RC
EOF
chmod 755 /usr/local/bin/artcraft-app-launch
echo "wrapper_v2_instalado"
echo "--- 3. verificacion: adj de un lanzamiento de prueba ---"
/usr/local/bin/artcraft-app-launch /usr/bin/vectorcraft &
WP=$!
sleep 4
AP=$(pgrep -x vectorcraft | head -1)
[ -n "$AP" ] && echo "app_pid=$AP adj=$(cat /proc/$AP/oom_score_adj 2>/dev/null)" || echo "app_no_visible"
sleep 2
pkill -x vectorcraft 2>/dev/null; kill $WP 2>/dev/null
L=$(ls -t /tmp/app-session-*.log | head -1)
echo "== log de la prueba =="; cat "$L" | head -8
echo "--- 4. salud ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a59.sh 2>&1
rm -f "$T/a59.sh"
echo "VEREDICTO: si la prueba muestra adj=0 en la app, el blindaje funciona y el usuario debe probar: abrir VectorCraft desde el dock y USARLA — con Termux:X11 en 'sin optimizacion de bateria' (Ajustes Android) la app deberia sobrevivir. Si escritura_denegada, el blindaje por proceso es imposible sin root y la unica cura es la de Android: desactivar optimizacion de bateria para Termux y Termux:X11 + wake-lock permanente."
echo "=== MISION-A59-BLINDAJE-APPS COMPLETE ==="
echo "### BRIDGE MARKER ###"