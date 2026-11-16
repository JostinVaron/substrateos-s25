echo "=== MISION-A49-ARTCRAFT-CRASH-INPUT — ¿crashea al interactuar? $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/ci.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
LOGDIR=/home/dexuser/.local/share/artcraft-launcher/logs
echo "--- 1. logs nuevos desde el crash del usuario (post-23:51) ---"
ls -la --time-style=full-iso "$LOGDIR" 2>/dev/null | tail -5
NEW=$(ls -t "$LOGDIR"/*.log 2>/dev/null | head -1)
echo "== contenido completo del log mas reciente ($NEW) =="
cat "$NEW" 2>/dev/null | grep -vE "ureq_proto" | tail -30
echo "--- 2. lanzar COMO EL DOCK (substrate-gpu-run) con stderr capturado ---"
substrate-gpu-run artcraft-launcher > /tmp/a49-out.log 2> /tmp/a49-err.log &
GP=$!
echo "pid=$GP"
VW=""
for i in $(seq 1 15); do
  sleep 2
  VW=$(wmctrl -l 2>/dev/null | grep -i craft | awk '{print $1}' | head -1)
  [ -n "$VW" ] && break
done
[ -z "$VW" ] && { echo "SIN_VENTANA_EN_30s"; kill $GP 2>/dev/null; exit 0; }
echo "ventana id=$VW nombre='$(xdotool getwindowname $VW)'"
GEO=$(xdotool getwindowgeometry --shell "$VW" 2>/dev/null | grep -E "^(X|Y|WIDTH|HEIGHT)" | tr '\n' ' ')
echo "geometria: $GEO"
read X Y W H <<< "$(xdotool getwindowgeometry --shell $VW | awk '/^X/{x=$2}/^Y/{y=$2}/^WIDTH/{w=$2}/^HEIGHT/{h=$2} END{print x, y, w, h}')"
CX=$((X + W/2)); CY=$((Y + H/2))
echo "--- 3. INTERACCION programatica (lo que A47 nunca hizo) ---"
xdotool windowactivate "$VW" 2>/dev/null; sleep 1
echo "foco_dado"
for i in 1 2 3; do
  xdotool mousemove $((CX - 100 + i*50)) $((CY - 80 + i*20)) 2>/dev/null; sleep 1
done
xdotool mousemove "$CX" "$CY" 2>/dev/null; sleep 1
xdotool click 1 2>/dev/null; echo "clic_centro_dado"; sleep 3
kill -0 $GP 2>/dev/null && echo "vivo_tras_clic" || echo "MUERTO_TRAS_CIRCULO_Y_CLIC"
xdotool key Tab 2>/dev/null; sleep 1
xdotool key Down 2>/dev/null; sleep 2
xdotool mousemove $((CX + 200)) $((CY + 150)) 2>/dev/null; xdotool click 1 2>/dev/null
echo "clic_derecha_abajo_dado"; sleep 3
xdotool key Escape 2>/dev/null; sleep 2
echo "--- 4. veredicto de la interaccion ---"
if kill -0 $GP 2>/dev/null; then
  echo "SOBREVIVIO_INTERACCION (sin crash)"
  kill $GP 2>/dev/null
  sleep 2
else
  wait $GP; RC=$?
  echo "CRASH_DURANTE_INTERACCION exit_code=$RC"
fi
echo "--- 5. stderr capturado (el panico, si hubo) ---"
echo "[bytes err=$(stat -c%s /tmp/a49-err.log 2>/dev/null || echo 0)]"
grep -vE "ureq_proto" /tmp/a49-err.log | tail -25
echo "--- 6. stdout capturado (sin ureq) ---"
grep -vE "ureq_proto" /tmp/a49-out.log | tail -15
echo "--- 7. dmesg por si fue segfault del kernel ---"
dmesg 2>/dev/null | tail -5 || echo "dmesg_no_disponible"
echo "--- 8. salud del escritorio ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/ci.sh 2>&1
rm -f "$T/ci.sh"
echo "VEREDICTO: arriba esta el exit code y el stderr en el momento exacto del crash con interaccion. Si SOBREVIVIO_INTERACCION y el usuario igual crashea, la diferencia restante es el hardware de entrada real (SPen/touch de la tablet via WTM) — pedirle reproducir con mouse normal. NO especular mas alla del dato."
echo "=== MISION-A49-ARTCRAFT-CRASH-INPUT COMPLETE ==="
echo "### BRIDGE MARKER ###"