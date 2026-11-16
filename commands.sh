echo "=== MISION-A29-R2 — Calculadora con login proot persistente $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
echo "--- 0. causa raiz de R1 ---"
echo "proot usa --kill-on-exit: la calc lanzada como hija de un login efimero murio al salir el bash -c. R2 usa login persistente (setsid) con la calc en exec."
echo "--- 1. ventanas antes ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'export DISPLAY=:0; wmctrl -l 2>/dev/null'
echo "--- 2. lanzando login PERSISTENTE con la calc en foreground ---"
setsid nohup proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -c '
export HOME=/home/dexuser DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)
export GSK_RENDERER=cairo GTK_A11Y=none NO_AT_BRIDGE=1
exec gnome-calculator
' > "$PREFIX/tmp/calc-a29r2.log" 2>&1 &
echo "login_persistente_pid=$!"
echo "--- 3. esperando ventana (max 30 s, xdotool/wmctrl) ---"
FOUND=""
for i in $(seq 1 15); do
  sleep 2
  FOUND=$(proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
export DISPLAY=:0
W=$(xdotool search --class "calc" 2>/dev/null | head -1)
[ -z "$W" ] && W=$(xdotool search --name "alc" 2>/dev/null | head -1)
echo "$W"' 2>/dev/null)
  [ -n "$FOUND" ] && { echo "ventana detectada a los ~$((i*2)) s"; break; }
done
echo "--- 4. verificacion con instrumentos corregidos ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
export DISPLAY=:0
echo "todas las ventanas (wmctrl -l):"
wmctrl -l 2>/dev/null
W=$(xdotool search --class "calc" 2>/dev/null | head -1)
[ -z "$W" ] && W=$(xdotool search --name "alc" 2>/dev/null | head -1)
if [ -n "$W" ]; then
  echo "VENTANA_CALC_ID=$W"
  echo "titulo: $(xdotool getwindowname "$W" 2>/dev/null)"
  xdotool getwindowgeometry "$W" 2>/dev/null
  xdotool windowactivate "$W" 2>/dev/null && echo "VENTANA_ACTIVADA_TRAER_AL_FRENTE"
else
  echo VENTANA_CALC_NO_HAY
fi'
echo "--- 5. log de la calc (si fallo, el por que esta aqui) ---"
tail -20 "$PREFIX/tmp/calc-a29r2.log" 2>/dev/null
echo "--- 6. captura de evidencia ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
export DISPLAY=:0
scrot -o /tmp/rt-dex/calc-a29r2.png 2>/dev/null
identify -format "colores=%k\n" /tmp/rt-dex/calc-a29r2.png 2>/dev/null'
echo "--- 7. el shell sobrevivio? ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO'
if [ -n "$FOUND" ]; then
  echo "VEREDICTO: CALC_ABIERTA_EN_PANTALLA — la Calculadora queda ABIERTA para verificacion visual humana. NO se declara exito total hasta que el dueno confirme verla."
  echo "para cerrarla despues: proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'DISPLAY=:0 xdotool search --class calc windowclose'"
else
  echo "VEREDICTO: CALC_NO_ARRANCO — log completo arriba; NO especular, leer el log."
fi
echo "=== MISION-A29-R2 COMPLETE ==="
echo "### BRIDGE MARKER ###"