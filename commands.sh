echo "=== MISION-A72-CAZADOR-EN-VIVO — capturar al asesino con escena limpia $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
RT="$PREFIX/tmp/rt-dex"
echo "--- 0. estado de flags phantom (re-verificar que sigan) ---"
adb connect 127.0.0.1:5555 >/dev/null 2>&1
echo "monitor_phantom_procs=$(adb -s 127.0.0.1:5555 shell settings get global settings_enable_monitor_phantom_procs 2>/dev/null | tr -d '\r')"
echo "max_phantom_processes=$(adb -s 127.0.0.1:5555 shell device_config get activity_manager max_phantom_processes 2>/dev/null | tr -d '\r')"
echo "--- 1. logcat en streaming desde AHORA (captura al asesino en el acto) ---"
CAP="$PREFIX/tmp/a72-logcat.cap"
adb -s 127.0.0.1:5555 shell logcat -v time 2>/dev/null > "$CAP" &
CAPPID=$!
sleep 2
echo "captura_iniciada pid=$CAPPID -> $CAP"
echo "--- 2. procstate de termux antes de la prueba ---"
adb -s 127.0.0.1:5555 shell dumpsys activity processes 2>/dev/null | grep -E "procstate=|oom" | grep -iE "termux" | head -4 || true
echo "--- 3. UNA SOLA sesion proot: lanzar FilmCraft y monitorear en su loop interno ---"
cat > "$RT/a72.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "== escritorio =="
pgrep -x gnome-shell >/dev/null && echo "SHELL_VIVO pid=$(pgrep -x gnome-shell | head -1)" || echo SHELL_MUERTO
FP=$(pgrep -x filmcraft | head -1)
[ -n "$FP" ] && echo "filmcraft_ya_viva pid=$FP — usando esa" || { echo "pidiendo filmcraft al broker por fifo..."; printf "filmcraft\n" > /dev/shm/launch.fifo 2>/dev/null || printf "filmcraft\n" > /proc/self/fd/1; }
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
FP=$(pgrep -x filmcraft | head -1)
[ -n "$FP" ] || { printf "filmcraft\n" > /tmp/launch.fifo; sleep 12; FP=$(pgrep -x filmcraft | head -1); }
echo "filmcraft_pid=${FP:-NO}"
if [ -n "$FP" ]; then
  T0=$(date +%s)
  for i in $(seq 1 48); do
    sleep 5
    EL=$(( $(date +%s) - T0 ))
    if kill -0 "$FP" 2>/dev/null; then
      [ $((i % 6)) -eq 0 ] && echo "t+${EL}s VIVA adj=$(cat /proc/$FP/oom_score_adj 2>/dev/null) rss=$(grep VmRSS /proc/$FP/status 2>/dev/null | awk "{print \$2}")kB"
    else
      echo "MURIO_EN_t+${EL}s pid_era=$FP"
      break
    fi
  done
  kill -0 "$FP" 2>/dev/null && echo "RESULTADO: FILMCRAFT SOBREVIVIO_4MIN_SESION_UNICA" || echo "RESULTADO: MURIO_EN_MONITOREO"
else
  echo "no_nacio"
  tail -4 /tmp/rt-dex/../app-live-filmcraft.log 2>/dev/null || true
fi' 2>&1
rm -f "$RT/a72.sh"
echo "--- 4. procstate de termux despues de la prueba ---"
adb -s 127.0.0.1:5555 shell dumpsys activity processes 2>/dev/null | grep -iE "termux" | head -6 || true
echo "--- 5. LA EVIDENCIA: logcat capturado en la ventana (decisiones de kill) ---"
sleep 2; kill $CAPPID 2>/dev/null
grep -iE "lmkd|phantom|Killing|killing.*termux|freeze|frozen" "$CAP" | grep -viE "No processes to kill" | tail -15 || echo "cero decisiones de kill en la ventana — sin agresores"
echo "== kills de lmkd (aunque digan 'no processes') =="
grep -c "No processes to kill" "$CAP" | xargs -I{} echo "intentos_barrido_lmkd={}"
echo "--- 6. estado final ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'pgrep -x filmcraft >/dev/null && echo FILMCRAFT_VIVA || echo FILMCRAFT_MUERTA; pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO' 2>/dev/null
pgrep -f app-broker-termux >/dev/null && echo BROKER_VIVO || echo BROKER_MUERTO
echo "VEREDICTO: si SOBREVIVIO con sesion unica — el monitoreo intensivo era parte del problema y el usuario prueba en uso normal. Si MURIO — la ventana capturada en \$CAP nombra al asesino exacto (lmkd con adj, phantom killer, o freezer) y eso define la cura definitiva."
echo "=== MISION-A72-CAZADOR-EN-VIVO COMPLETE ==="
echo "### BRIDGE MARKER ###"