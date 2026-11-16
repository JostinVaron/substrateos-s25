echo "=== MISION-A47-ARTCRAFT-CRASH-DIAG — por que crashea el catalogo $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/cd.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
LOGDIR=/home/dexuser/.local/share/artcraft-launcher/logs
echo "--- 1. log oficial del launcher (crash previo del usuario) ---"
ls -la "$LOGDIR" 2>/dev/null | tail -3
LATEST=$(ls -t "$LOGDIR"/*.log 2>/dev/null | head -1)
echo "== ultimas 25 lineas de $LATEST =="
tail -25 "$LATEST" 2>/dev/null
echo "== lineas con panic/error/fatal/warn en todo el log =="
grep -inE "panic|error|fatal|SIGSEGV|abort|killed|exit" "$LATEST" 2>/dev/null | tail -15
echo "--- 2. reproducir: lanzar con GPU (como el dock) y vigilar 90 s ---"
substrate-gpu-run artcraft-launcher > /tmp/a47-gui.log 2>&1 &
GP=$!
echo "pid=$GP"
CRASHED=""
for i in $(seq 1 45); do
  sleep 2
  if ! kill -0 $GP 2>/dev/null; then
    wait $GP; RC=$?
    echo "CRASH_GPU_EN_$((i*2))s exit_code=$RC"
    CRASHED="si"
    break
  fi
  [ $((i % 10)) -eq 0 ] && echo "...vivo a los $((i*2))s, ventanas: $(wmctrl -l 2>/dev/null | grep -ci craft)"
done
[ -z "$CRASHED" ] && { echo "SOBREVIVIO_90s (sin crash en esta pasada)"; kill $GP 2>/dev/null; }
echo "--- 3. log de la GUI de esta pasada ---"
tail -15 /tmp/a47-gui.log
grep -inE "panic|error|fatal|SIGSEGV|abort" /tmp/a47-gui.log | tail -10
echo "--- 4. diagnostico A/B: mismo launcher con render SOFTWARE (si el GL es el asesino, este sobrevive) ---"
HOME=/home/dexuser LIBGL_ALWAYS_SOFTWARE=1 GSK_RENDERER=cairo artcraft-launcher > /tmp/a47-sw.log 2>&1 &
SP=$!
SW=""
for i in $(seq 1 45); do
  sleep 2
  if ! kill -0 $SP 2>/dev/null; then
    wait $SP; RC2=$?
    echo "CRASH_SOFTWARE_EN_$((i*2))s exit_code=$RC2"
    SW="crash"
    break
  fi
  [ $((i % 10)) -eq 0 ] && echo "...software vivo a los $((i*2))s"
done
[ -z "$SW" ] && { echo "SOBREVIVIO_SOFTWARE_90s"; kill $SP 2>/dev/null; echo "senal: el problema es el GL/GPU path"; }
tail -8 /tmp/a47-sw.log
echo "--- 5. salud final ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
free -h | head -2
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/cd.sh 2>&1
rm -f "$T/cd.sh"
echo "VEREDICTO: el porque real del crash esta arriba (exit code + log + resultado A/B GPU-vs-software). Con eso se elige la cura: flags al wrapper o icono de dock, NO a ciegas."
echo "=== MISION-A47-ARTCRAFT-CRASH-DIAG COMPLETE ==="
echo "### BRIDGE MARKER ###"