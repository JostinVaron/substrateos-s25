echo "=== MISION-A39-VSCODE-UNO — parche correcto + lanzamiento en sesion unica viva $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/vsone.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 0. entorno X alcanzable? ---"
xdpyinfo 2>/dev/null | grep -m1 "name of display" || echo "X_NO_ALCANZABLE"
echo "--- 1. parche CORRECTO a los .desktop reales (prefijo exacto, respaldo previo) ---"
for D in /usr/share/applications/com.microsoft.VSCode.desktop /usr/share/applications/com.microsoft.VSCode.UrlHandler.desktop; do
  [ -f "$D" ] || continue
  cp -n "$D" "$D.bak-bridge" 2>/dev/null
  sed -i 's|^Exec=/usr/share/code/code|Exec=/usr/local/bin/vscode-proot|' "$D"
  echo "ahora $D:"; grep "^Exec=" "$D"
done
update-desktop-database /usr/share/applications 2>/dev/null || true
echo "--- 2. lanzar code DENTRO de esta misma sesion (nohup interno, nada externo) ---"
nohup /usr/local/bin/vscode-proot > /tmp/vscode-a39.log 2>&1 &
CODE_PID=$!
echo "code_pid=$CODE_PID"
echo "--- 3. monitoreo proceso+ventana hasta 150 s ---"
VW=""
for i in $(seq 1 75); do
  sleep 2
  kill -0 $CODE_PID 2>/dev/null || { echo "PROCESO_MURIO_EN_$((i*2))s"; break; }
  VW=$(xdotool search --class -i "code" 2>/dev/null | while read w; do n=$(xdotool getwindowname "$w" 2>/dev/null); case "$n" in *Visual*) echo "$w"; break;; esac; done)
  [ -n "$VW" ] && { echo "VENTANA_A_LOS_$((i*2))s id=$VW nombre='$(xdotool getwindowname $VW)'"; break; }
done
echo "--- 4. procesos code vivos ---"
pgrep -a -f "code/code" 2>/dev/null | head -5 || echo "ninguno"
echo "--- 5. ventanas X ---"
wmctrl -l 2>/dev/null || echo "wmctrl_sin_salida"
echo "--- 6. log de Electron (head 25) ---"
head -25 /tmp/vscode-a39.log
echo "--- 7. captura ---"
scrot -o /tmp/rt-dex/vscode-a39.png 2>/dev/null
identify -format 'colores=%k\n' /tmp/rt-dex/vscode-a39.png 2>/dev/null
if [ -n "$VW" ]; then
  xdotool windowactivate "$VW" 2>/dev/null && echo VSCODE_AL_FRENTE
  echo "VEREDICTO_A39: VENTANA_CONFIRMADA_EN_SESION_VIVA"
else
  echo "VEREDICTO_A39: SIN_VENTANA — seccion 6 contiene el porque real, NO especular"
fi
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/vsone.sh 2>&1
rm -f "$T/vsone.sh"
echo "=== MISION-A39-VSCODE-UNO COMPLETE ==="
echo "### BRIDGE MARKER ###"