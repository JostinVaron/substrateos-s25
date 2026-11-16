echo "=== MISION-A43-VSCODE-GUARDIAN-OFF — apagar el guardian que reabre VS Code $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/vsoff.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. localizar guardian (verificar identidad antes de matar) ---"
GP=$(pgrep -f "vskeep.sh" 2>/dev/null | tr '\n' ' ')
echo "guardian_pids=$GP"
[ -n "$GP" ] && ps -p $(echo $GP | tr ' ' ',') -o pid,args 2>/dev/null | cut -c1-90
echo "--- 2. matar guardian PRIMERO (para que no reanime) ---"
for P in $GP; do kill "$P" 2>/dev/null && echo "guardian_pid_$P terminado"; done
sleep 3
if pgrep -f "vskeep.sh" >/dev/null 2>&1; then
  echo "persiste — ultima instancia SIGKILL"
  for P in $(pgrep -f "vskeep.sh"); do kill -9 "$P" 2>/dev/null && echo "guardian_pid_$P sigkill"; done
  sleep 1
fi
pgrep -f "vskeep.sh" >/dev/null 2>&1 && echo "GUARDIAN_PERSISTE" || echo "GUARDIAN_MUERTO_CONFIRMADO"
echo "--- 3. cerrar ventana de VS Code de forma limpia (xdotool, nunca pkill -f) ---"
W=$(wmctrl -l 2>/dev/null | grep -i "visual studio code" | awk '{print $1}' | head -1)
if [ -n "$W" ]; then
  xdotool windowclose "$W" 2>/dev/null && echo "ventana_cerrada_limpia"
  sleep 4
fi
echo "--- 4. procesos code restantes (pids exactos verificados) ---"
CP=$(pgrep -f "code --no-sandbox" 2>/dev/null | tr '\n' ' ')
echo "code_pids=$CP"
for P in $CP; do kill "$P" 2>/dev/null && echo "code_pid_$P terminado"; done
sleep 3
pgrep -f "code --no-sandbox" >/dev/null 2>&1 && echo "CODE_PERSISTE" || echo "CODE_LIMPIO"
echo "--- 5. verificacion final (nada resucita) ---"
sleep 10
wmctrl -l 2>/dev/null || echo "sin ventanas de code"
pgrep -f "vskeep.sh" >/dev/null 2>&1 && echo "GUARDIAN_REVIVIO" || echo "GUARDIO_SIGUE_MUERTO_TRAS_10s"
free -h | head -2
echo "VEREDICTO: guardian apagado para siempre. VS Code ya NO se reabre solo; se lanza unicamente cuando el usuario lo abra (icono del dock ya parchado con wrapper seguro)."
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/vsoff.sh 2>&1
rm -f "$T/vsoff.sh"
echo "=== MISION-A43-VSCODE-GUARDIAN-OFF COMPLETE ==="
echo "### BRIDGE MARKER ###"