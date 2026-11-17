echo "=== MISION-A68-DX-CRASHES-USO — diagnostico SOLO LECTURA de crashes durante el uso $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/a68.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. informe de crash de EffectCraft (el que mostro el dialogo) ---"
CR="/home/dexuser/.config/effectcraft/Logs/Crash Reports/crash-25653-1794880223726636206.txt"
if [ -f "$CR" ]; then echo "== contenido completo =="; cat "$CR"; else echo "no encontrado — directorio:"; ls -lt "/home/dexuser/.config/effectcraft/Logs/Crash Reports" 2>/dev/null | head -5; fi
echo "--- 2. informes mas recientes de TODAS las apps craft ---"
find /home/dexuser/.config -type d -iname "Crash Reports" 2>/dev/null | while read -r D; do
  LATEST=$(ls -t "$D"/*.txt 2>/dev/null | head -1)
  [ -n "$LATEST" ] && { echo "== $LATEST =="; head -25 "$LATEST"; echo; }
done
echo "--- 3. stderr capturado por el broker (salida viva de cada app) ---"
for L in /tmp/app-live-effectcraft.log /tmp/app-live-filmcraft.log /tmp/app-live-photocraft.log /tmp/app-live-lightcraft.log /tmp/app-live-vectorcraft.log /tmp/app-live.log; do
  [ -f "$L" ] && { echo "== $L (ultimas 10 sin ruido GPU) =="; grep -vE "MESA-LOADER|vblank|ureq_proto|display GPUs" "$L" | tail -10; echo; }
done
echo "--- 4. logs internos de apps modificados hace <90 min ---"
find /home/dexuser/.config -maxdepth 3 -name "*.log" -mmin -90 2>/dev/null | while read -r F; do
  echo "== $F =="; tail -6 "$F"; echo
done
echo "--- 5. procesos craft vivos AHORA y su oom_score_adj ---"
ps -eo pid=,comm=,rss= 2>/dev/null | grep -iE "craft" | grep -v grep | head -8
ps -eo pid=,comm= 2>/dev/null | awk '$2 ~ /craft/ {print $1}' | head -4 | while read -r P; do
  echo "pid=$P adj=$(cat /proc/$P/oom_score_adj 2>/dev/null) rss=$(grep VmRSS /proc/$P/status 2>/dev/null | awk '{print $2}')kB"
done
echo "--- 6. memoria y swap ---"
free -m | head -2
grep -E "MemAvailable|SwapTotal|SwapFree" /proc/meminfo
echo "--- 7. salud del escritorio ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a68.sh 2>&1
rm -f "$T/a68.sh"
echo "--- 8. logcat Android: LMKD o kgsl/GPU hablando de tus procesos ---"
logcat -d 2>/dev/null | grep -iE "kill|kgsl|gpu" | grep -iE "craft|termux|adreno" | tail -10 || echo "logcat vacio (sin permiso es normal)"
echo "VEREDICTO: firma de cada informe decide el frente: exit 137 = LMKD persiste (broker no cubrio ese caso); SIGSEGV/abort en render = GPU Adreno bajo carga sostenida; panic runtime = bug de app o syscall no soportada por proot. Solo lectura — ningun cambio aplicado."
echo "=== MISION-A68-DX-CRASHES-USO COMPLETE ==="
echo "### BRIDGE MARKER ###"