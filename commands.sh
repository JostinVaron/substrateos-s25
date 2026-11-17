echo "=== MISION-A73-DIFERENCIAL-EN-SESION — camino viejo en-sesion vs broker, logcat limpio $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
RT="$PREFIX/tmp/rt-dex"
ADB="adb -s 127.0.0.1:5555"
echo "--- 0. limpiar logcat y contar phantoms ANTES ---"
adb connect 127.0.0.1:5555 >/dev/null 2>&1
$ADB shell logcat -c 2>/dev/null && echo "logcat_limpiado"
PH_BEFORE=$($ADB shell dumpsys activity processes 2>/dev/null | grep -c "PhantomProcessRecord" | tr -d '\r')
echo "phantom_records_antes=${PH_BEFORE:-0}"
CAP="$PREFIX/tmp/a73-logcat.cap"
$ADB shell logcat -v time 2>/dev/null > "$CAP" &
CAPPID=$!
echo "--- 1. UNA sola sesion proot: lanzar FilmCraft EN-SESION (camino de los 18min) y monitorear adentro ---"
cat > "$RT/a73.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/home/dexuser
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
export XDG_CURRENT_DESKTOP=ubuntu:GNOME XDG_SESSION_TYPE=x11
pgrep -x gnome-shell >/dev/null && echo "SHELL_VIVO" || echo SHELL_MUERTO
pkill -x filmcraft 2>/dev/null; sleep 1
echo "lanzando filmcraft EN-SESION (mismo arbol que el escritorio)..."
setsid /usr/local/bin/substrate-gpu-run /usr/bin/filmcraft > /tmp/rt-dex/a73-filmcraft-en-sesion.log 2>&1 &
sleep 10
FP=$(pgrep -x filmcraft | head -1)
echo "filmcraft_pid=${FP:-NO_NACIO}"
if [ -n "$FP" ]; then
  echo "adj_al_nacer=$(cat /proc/$FP/oom_score_adj 2>/dev/null)"
  T0=$(date +%s); DEAD=""
  for i in $(seq 1 48); do
    sleep 5
    EL=$(( $(date +%s) - T0 ))
    if kill -0 "$FP" 2>/dev/null; then
      [ $((i % 6)) -eq 0 ] && echo "t+${EL}s VIVA adj=$(cat /proc/$FP/oom_score_adj 2>/dev/null) rss=$(grep VmRSS /proc/$FP/status 2>/dev/null | awk '{print $2}')kB"
    else
      echo "MURIO_EN_t+${EL}s"; date -u +%FT%T.%NZ > /tmp/rt-dex/a73-death-time.txt; DEAD=si; break
    fi
  done
  [ -z "$DEAD" ] && echo "RESULTADO: SOBREVIVIO_4MIN_EN_SESION" || echo "RESULTADO: MURIO_EN_SESION"
  tail -3 /tmp/rt-dex/a73-filmcraft-en-sesion.log 2>/dev/null
else
  echo "no_nacio"; tail -5 /tmp/rt-dex/a73-filmcraft-en-sesion.log 2>/dev/null
fi
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/rt-dex/a73.sh 2>&1
rm -f "$RT/a73.sh"
echo "--- 2. phantoms DESPUES ---"
sleep 2
PH_AFTER=$($ADB shell dumpsys activity processes 2>/dev/null | grep -c "PhantomProcessRecord" | tr -d '\r')
echo "phantom_records_despues=${PH_AFTER:-0}"
kill $CAPPID 2>/dev/null
echo "--- 3. firma de muerte: ventana COMPLETA sin filtrar (todas las lineas alrededor de kills) ---"
grep -nE "Killing|killed|died|Kill|am_kill|lmkd.*kill|Freeze|freeze|phantom" "$CAP" | tail -25 || echo "sin lineas de muerte en toda la ventana"
echo "== lmkd activity (resumen) =="
grep -cE "No processes to kill" "$CAP" | xargs -I{} echo "barridos_sin_victimas={}"
grep -E "lmkd" "$CAP" | grep -v "No processes to kill" | tail -6
echo "== dmesg (kernel: OOM o lmkd nativo) =="
$ADB shell dmesg 2>/dev/null | grep -iE "oom|kill|lowmem" | tail -5 || echo "dmesg sin acceso o sin kills del kernel"
echo "--- 4. estado final ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'pgrep -x filmcraft >/dev/null && echo FILMCRAFT_VIVA || echo FILMCRAFT_MUERTA; pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO' 2>/dev/null
pgrep -f app-broker-termux >/dev/null && echo BROKER_VIVO || echo BROKER_MUERTO
echo "VEREDICTO: SOBREVIVIO_EN_SESION = el broker (arbol proot separado) es la vulnerabilidad — cura: mover el lanzamiento del broker a dentro de la sesion (fifo escrito por dock, sesion consume y lanza en su arbol). MURIO tambien en sesion = la firma completa de la ventana dice quien (FreecessHandler/lmkd/AMS) y apuntamos alla."
echo "=== MISION-A73-DIFERENCIAL-EN-SESION COMPLETE ==="
echo "### BRIDGE MARKER ###"