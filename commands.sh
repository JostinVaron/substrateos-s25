echo "=== MISION-A50-ARTCRAFT-CRASH-CATCH — atrapar el panic del usuario en vivo $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/cc.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. dispositivos XInput reales (tus touch/pen/teclado via WTM) ---"
command -v xinput >/dev/null && xinput list 2>&1 | head -15 || echo "xinput_no_instalado"
echo "--- 2. resolucion actual del display ---"
xdpyinfo 2>/dev/null | grep -E "dimensions"
echo "--- 3. wrapper de captura para el dock ---"
cat > /usr/local/bin/artcraft-dock-launch <<'EOX'
#!/bin/bash
# Wrapper de captura — cada apertura del dock queda registrada con stderr y exit code
TS=$(date -u +%Y%m%dT%H%M%SZ)
LOG=/tmp/artcraft-session-$TS.log
echo "[$(date -u +%FT%TZ)] apertura desde dock, HOME=$HOME" > "$LOG"
substrate-gpu-run artcraft-launcher >> "$LOG" 2>&1
RC=$?
echo "[$(date -u +%FT%TZ)] EXIT_CODE=$RC" >> "$LOG"
exit $RC
EOX
chmod 755 /usr/local/bin/artcraft-dock-launch
echo "wrapper_instalado"
echo "--- 4. repuntar icono del dock al wrapper de captura ---"
sed -i 's|^Exec=.*|Exec=/usr/local/bin/artcraft-dock-launch|' /usr/share/applications/artcraft-gpu.desktop
grep "^Exec=" /usr/share/applications/artcraft-gpu.desktop
update-desktop-database /usr/share/applications 2>/dev/null || true
echo "--- 5. prueba del wrapper (5 s, luego cierre limpio) ---"
/usr/local/bin/artcraft-dock-launch &
WP=$!
sleep 5
LATEST=$(ls -t /tmp/artcraft-session-*.log | head -1)
echo "log_de_prueba=$LATEST"
tail -3 "$LATEST" | grep -vE "ureq_proto"
W=$(wmctrl -l 2>/dev/null | grep -i craft | awk '{print $1}' | head -1)
[ -n "$W" ] && xdotool windowclose "$W" 2>/dev/null && echo "cierre_limpio_prueba_ok"
sleep 2
kill $WP 2>/dev/null
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/cc.sh 2>&1
rm -f "$T/cc.sh"
echo "VEREDICTO: wrapper activo. PROXIMO PASO HUMANO: abrir el icono del dock normalmente, usarlo hasta que crashee (si crashea), y avisar — el panic exacto estara escrito en /tmp/artcraft-session-*.log."
echo "=== MISION-A50-ARTCRAFT-CRASH-CATCH COMPLETE ==="
echo "### BRIDGE MARKER ###"