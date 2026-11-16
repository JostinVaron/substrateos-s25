echo "=== MISION-A41-VSCODE-KEEP — guardian persistente para VS Code $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/vskeep.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
R=/tmp/vskeep-result.txt
{
echo "[$(date -u +%T)] guardian iniciado dbus=${DBUS_SESSION_BUS_ADDRESS:-VACIO}"
nohup /usr/local/bin/vscode-proot > /tmp/vs-a41-code.log 2>&1 &
CP=$!
echo "[$(date -u +%T)] code_pid=$CP"
W=""
for i in $(seq 1 45); do
  sleep 2
  W=$(wmctrl -l 2>/dev/null | grep -i "visual studio code" | awk '{print $1}' | head -1)
  [ -n "$W" ] && { echo "[$(date -u +%T)] VENTANA_EN_$((i*2))s id=$W"; break; }
done
if [ -n "$W" ]; then
  xdotool windowactivate "$W" 2>/dev/null; sleep 2
  scrot -o /tmp/rt-dex/vscode-a41.png 2>/dev/null
  echo "titulo='$(xdotool getwindowname $W 2>/dev/null)'"
  echo "colores=$(identify -format %k /tmp/rt-dex/vscode-a41.png 2>/dev/null)"
  echo "VEREDICTO: VSCODE_VIVO_Y_VISIBLE"
else
  echo "VEREDICTO: SIN_VENTANA_EN_90s"
  echo "--- log code head 20 ---"; head -20 /tmp/vs-a41-code.log
fi
} > "$R" 2>&1
echo "[$(date -u +%T)] guardian entrando en keepalive (no cierra nunca)"
while :; do
  sleep 20
  wmctrl -l 2>/dev/null | grep -qi "visual studio code" || {
    echo "[$(date -u +%T)] ventana ausente — reanimando" >> "$R"
    nohup /usr/local/bin/vscode-proot >> /tmp/vs-a41-code.log 2>&1 &
  }
done
EOS
setsid nohup proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/vskeep.sh > "$T/vs-a41-launch.log" 2>&1 &
echo "guardian_pid=$! (sesion proot PERSISTENTE — nunca se cierra)"
echo "--- esperando 110 s a que el guardian haga su trabajo ---"
sleep 110
echo "--- resultado del guardian ---"
proot-distro login ubuntu-gnome --shared-tmp -- cat /tmp/vskeep-result.txt 2>&1
echo "--- guardian vivo en Termux? ---"
ps -A -o pid,args 2>/dev/null | grep "[v]skeep" | head -2 || echo "GUARDIAN_MUERTO"
rm -f "$T/vskeep.sh"
echo "=== MISION-A41-VSCODE-KEEP COMPLETE ==="
echo "### BRIDGE MARKER ###"