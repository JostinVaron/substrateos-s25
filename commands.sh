echo "=== MISION-A75-TRAMPA-REPRODUCCION — capturar la muerte durante reproduccion de video $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
RT="$PREFIX/tmp/rt-dex"
echo "--- 0. salud previa ---"
RPID=$(cat "$RT/app-runner.pid" 2>/dev/null)
kill -0 ${RPID:-99999} 2>/dev/null && echo "runner_vivo pid=$RPID" || echo "runner_muerto"
adb connect 127.0.0.1:5555 >/dev/null 2>&1
adb -s 127.0.0.1:5555 shell logcat -c 2>/dev/null
CAP="$PREFIX/tmp/a75-logcat.cap"
adb -s 127.0.0.1:5555 shell logcat -v time 2>/dev/null > "$CAP" &
CAPPID=$!
echo "logcat_capturando pid=$CAPPID"
echo "--- 1. vigilante interno (mismo arbol del runner, no efimero) por 4 min ---"
cat > "$RT/a75-watch.sh" <<'WATCH'
#!/bin/bash
# Vigilante interno: corre dentro del arbol del runner. Muestrea filmcraft
# cada 2s; al morir escribe la firma forense con PSI del segundo previo.
LOG=/tmp/rt-dex/a75-muestreo.log
FIRMA=/tmp/rt-dex/a75-firma-muerte.txt
[ -p /tmp/launch.fifo ] || mkfifo /tmp/launch.fifo
echo "watch_iniciado $(date -u +%FT%T.%NZ) pid=$$" > "$LOG"
FP=$(pgrep -x filmcraft | head -1)
[ -z "$FP" ] && { printf "filmcraft\n" > /tmp/launch.fifo; sleep 10; FP=$(pgrep -x filmcraft | head -1); }
echo "filmcraft_pid=${FP:-NO}" >> "$LOG"
[ -z "$FP" ] && { echo "no_nacio" >> "$LOG"; exit 0; }
LAST_PSI=""
T0=$(date +%s)
for i in $(seq 1 120); do
  if kill -0 "$FP" 2>/dev/null; then
    PSI=$(grep -E "some avg10" /proc/pressure/memory 2>/dev/null | head -1 | tr -d '\n')
    GPU=$(grep -E "full avg10" /proc/pressure/cpu 2>/dev/null | head -1 | tr -d '\n')
    RSS=$(grep VmRSS /proc/$FP/status 2>/dev/null | awk '{print $2}')
    ADJ=$(cat /proc/$FP/oom_score_adj 2>/dev/null)
    echo "t+$(( $(date +%s) - T0 ))s viva rss=${RSS}kB adj=$ADJ" >> "$LOG"
    LAST_PSI="$PSI | $GPU"
    sleep 2
  else
    {
      echo "=== MUERTE EN t+$(( $(date +%s) - T0 ))s ==="
      echo "hora_utc=$(date -u +%FT%T.%NZ)"
      echo "pid_era=$FP"
      echo "psi_ultimo=$LAST_PSI"
      echo "meminfo_al_morir:"; grep -E "MemAvailable|SwapFree" /proc/meminfo | head -2
      echo "== ultimas 15 lineas del log de la app =="
      tail -15 /tmp/app-live-filmcraft.log 2>/dev/null
    } > "$FIRMA"
    echo "FIRMA_ESCRITA" >> "$LOG"
    break
  fi
done
kill -0 "$FP" 2>/dev/null && echo "RESULTADO: SOBREVIVIO_4MIN_REPRODUCIENDO" >> "$LOG" || true
WATCH
chmod 755 "$RT/a75-watch.sh"
echo filmcraft > "$PREFIX/tmp/launch.fifo"
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/rt-dex/a75-watch.sh 2>&1 | tail -3
echo "--- 2. si sobrevivio, la firma no existe; si murio, leer la firma ---"
cat > "$RT/a75-read.sh" <<'RD'
#!/bin/bash
echo "== muestreo (ultimas 12 lineas) =="
tail -12 /tmp/rt-dex/a75-muestreo.log 2>/dev/null
echo "== firma de muerte (si existe) =="
cat /tmp/rt-dex/a75-firma-muerte.txt 2>/dev/null || echo "sin firma — sobrevivio o no murio en la ventana"
echo "== resultado =="
grep RESULTADO /tmp/rt-dex/a75-muestreo.log 2>/dev/null || echo "muerte_dentro_de_ventana"
RD
chmod 755 "$RT/a75-read.sh"
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/rt-dex/a75-read.sh 2>&1
rm -f "$RT/a75-watch.sh" "$RT/a75-read.sh"
echo "--- 3. logcat Android: decisiones de kill en la ventana ---"
sleep 2; kill $CAPPID 2>/dev/null
grep -iE "lmkd|Freecess|phantom.*died|Killing|freeze.*termux|am_kill" "$CAP" | grep -viE "No processes to kill" | tail -12 || echo "sin agresores en logcat"
echo "== barridos lmkd =="
grep -c "No processes to kill" "$CAP" | xargs -I{} echo "barridos={}"
grep -E "lmkd" "$CAP" | grep -v "No processes" | tail -4
echo "--- 4. estado final ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'pgrep -x filmcraft >/dev/null && echo FILMCRAFT_VIVA || echo FILMCRAFT_MUERTA' 2>/dev/null
RPID=$(cat "$RT/app-runner.pid" 2>/dev/null); kill -0 ${RPID:-99999} 2>/dev/null && echo "RUNNER_VIVO pid=$RPID" || echo RUNNER_MUERTO
echo "VEREDICTO: si la firma muestra muerte con PSI alto de memoria = el video empuja la presion y OneUI mata al arbol completo; si la firma muestra app viva pero proot signal 9 = asesino externo (lmkd/Freecess); si sobrevivio = la reproduccion murio antes de la trampa y repetir con el usuario reproduciendo DURANTE la ventana."
echo "=== MISION-A75-TRAMPA-REPRODUCCION COMPLETE ==="
echo "### BRIDGE MARKER ###"