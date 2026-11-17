echo "=== MISION-A56-TRAMPA-APPS — trampa de captura para las 4 apps $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/a56.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. wrapper de captura para apps ---"
cat > /usr/local/bin/artcraft-app-launch <<'EOF'
#!/bin/bash
# Trampa de captura para apps ArtCraft: stderr + exit code + RAM en vivo.
TS=$(date -u +%Y%m%dT%H%M%SZ)
LOG=/tmp/app-session-$TS.log
echo "[$(date -u +%FT%TZ)] app=$1 pid_inicio" > "$LOG"
# muestreador de memoria: si la app muere con RAM desplomada = OOM; si muere con panic = winit
( while true; do sleep 3; echo "[$(date -u +%FT%TZ)] rss_kb=$(ps -o rss= -p $PPID 2>/dev/null | tr -d ' ') memavail_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')" >> "$LOG"; done ) &
SAMP=$!
substrate-gpu-run "$@" >> "$LOG" 2>&1
RC=$?
kill $SAMP 2>/dev/null
echo "[$(date -u +%FT%TZ)] EXIT_CODE=$RC" >> "$LOG"
exit $RC
EOF
chmod 755 /usr/local/bin/artcraft-app-launch
echo wrapper_ok
echo "--- 2. repuntar los .desktop de las 4 apps al wrapper ---"
for PKG in vectorcraft photocraft filmcraft lightcraft; do
  D=$(dpkg -L $PKG 2>/dev/null | grep -E "\.desktop$" | head -1)
  if [ -n "$D" ]; then
    BIN=$(grep "^Exec=" "$D" | head -1 | sed 's/^Exec=//' | awk '{print $1}')
    [ -n "$BIN" ] && sed -i "s|^Exec=.*|Exec=/usr/local/bin/artcraft-app-launch $BIN|" "$D" && echo "$PKG: $D -> trampa ($BIN)"
  else
    echo "$PKG: sin .desktop"
  fi
done
update-desktop-database /usr/share/applications 2>/dev/null || true
echo "--- 3. verificar trampas activas ---"
grep -l "artcraft-app-launch" /usr/share/applications/*.desktop 2>/dev/null | head -5
echo "--- 4. borrar logs viejos de app (mantener los nuevos limpios) ---"
find /tmp -name "app-session-*.log" -mmin +60 -delete 2>/dev/null; echo limpieza_ok
echo "--- 5. salud ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a56.sh 2>&1
rm -f "$T/a56.sh"
echo "VEREDICTO: trampas puestas. PROXIMO PASO HUMANO: abrir cada app desde el dock, usarla hasta que crashee (si crashea), y avisar — cada crash quedara grabado en /tmp/app-session-*.log con exit code y RAM en vivo: panic winit = exit 101 con texto; RAM agotada = exit 137 con memavail desplomado. Con la firma de UN crash se decide la cura."
echo "=== MISION-A56-TRAMPA-APPS COMPLETE ==="
echo "### BRIDGE MARKER ###"