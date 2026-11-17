echo "=== MISION-A55-OOM-VS-WINIT — firma del crash de las apps $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
echo "--- 1. LADO ANDROID (Termux, fuera del proot): la evidencia del sospechoso OOM ---"
echo "== RAM del telefono (la que Android ve) =="
free -h | head -2
grep -E "^(MemTotal|MemAvailable|SwapTotal|SwapFree|Committed_AS)" /proc/meminfo
echo "== PSI: presion de memoria del kernel (some = cuello, full = matando) =="
cat /proc/pressure/memory 2>/dev/null || echo "sin PSI"
echo "== contador de kills OOM del kernel (desde el arranque) =="
grep -E "^(oom_kill|pgmajfault)" /proc/vmstat 2>/dev/null || echo "sin vmstat"
echo "== logcat: muertes por LMKD (lo que mato a Firefox) =="
logcat -d 2>/dev/null | grep -iE "lowmemorykiller|lmkd|kill.*process|out of memory" | tail -12 || echo "logcat_no_accesible"
echo "== Top consumidores de RAM vistos por Android (top 8) =="
ps -eo rss,comm --sort=-rss 2>/dev/null | head -9
echo "--- 2. LADO PROOT: firma del crash de las apps ArtCraft ---"
cat > "$T/a55.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "== binarios instalados por las 4 apps =="
dpkg -L vectorcraft 2>/dev/null | grep -E "bin/" | head -3
APPBIN=$(dpkg -L vectorcraft 2>/dev/null | grep -E "/(bin|opt)/" | grep -vE "\.(desktop|png|xml|md)$" | head -1)
echo "app_bin=${APPBIN:-NO_ENCONTRADO}"
[ -z "$APPBIN" ] && { echo "buscando binario alternativo..."; ls /usr/local/bin/ 2>/dev/null | grep -iE "vector|craft" | head -4; }
echo "== hay logs propios de las apps? =="
ls /home/dexuser/.local/share/ 2>/dev/null | grep -iE "craft" 
find /home/dexuser/.local/share -name "*.log" -mmin -60 2>/dev/null | head -4
echo "== lanzar VectorCraft MONITORIZADO con captura (trampa del wrapper otra vez) =="
export HOME=/home/dexuser
TS=$(date -u +%Y%m%dT%H%M%SZ)
LOG=/tmp/app-session-$TS.log
substrate-gpu-run "$APPBIN" > "$LOG" 2>&1 &
AP=$!
echo "pid=$AP log=$LOG"
DEAD=""
for i in $(seq 1 30); do
  sleep 2
  if ! kill -0 $AP 2>/dev/null; then
    wait $AP; RC=$?
    echo "MURIO_EN_$((i*2))s EXIT=$RC"
    DEAD="si"; break
  fi
  RSS=$(ps -o rss= -p $AP 2>/dev/null | tr -d ' ')
  AV=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  [ $((i % 3)) -eq 0 ] && echo "t=$((i*2))s rss_kb=${RSS} memavail_kb=$AV"
done
[ -z "$DEAD" ] && { echo "SOBREVIVIO_60s"; kill $AP 2>/dev/null; }
echo "== FIRMA: stderr de la app (panic winit = exit 101 con texto; SIGKILL OOM = 137 en silencio) =="
echo "[bytes log=$(stat -c%s "$LOG" 2>/dev/null || echo 0)]"
grep -vE "ureq_proto|MESA" "$LOG" | tail -12
echo "== PSI y oom_kill DESPUES de la prueba (comparar con antes) =="
cat /proc/pressure/memory 2>/dev/null
grep -E "^oom_kill" /proc/vmstat 2>/dev/null
echo "== salud =="
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a55.sh 2>&1
rm -f "$T/a55.sh"
echo "VEREDICTO: la firma decide. EXIT=137/9 sin stderr + MemAvailable bajo + oom_kill subiendo = RAM AGOTADA (cura: disciplina de memoria, no parches). EXIT=101 con panic winit = mismo bug del launcher (cura distinta). Leer ambos lados antes de concluir."
echo "=== MISION-A55-OOM-VS-WINIT COMPLETE ==="
echo "### BRIDGE MARKER ###"