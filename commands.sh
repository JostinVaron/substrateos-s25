echo "=== MISION-A70-REINICIO-LIMPIO-PRUEBA-FILMCRAFT — reinicio total + prueba de supervivencia real $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
RT="$PREFIX/tmp/rt-dex"
echo "--- 1. loop v6 corriendo? ---"
LOCKV6="$HOME/substrate/bridge/v6.lock"
[ -f "$LOCKV6" ] && { P=$(cat "$LOCKV6"); kill -0 "$P" 2>/dev/null && echo "loop_v6_VIVO pid=$P" || echo "loop_v6_MUERTO_LOCK_VIEJO"; } || echo "sin lock v6 — verificar arranque manual"
echo "--- 2. guardián anti-LMKD activo (re-aplicar por si acaso) ---"
adb connect 127.0.0.1:5555 >/dev/null 2>&1
adb -s 127.0.0.1:5555 shell settings put global settings_enable_monitor_phantom_procs false >/dev/null 2>&1 && echo "monitor=false OK"
adb -s 127.0.0.1:5555 shell device_config set_sync_disabled_for_tests persistent >/dev/null 2>&1
adb -s 127.0.0.1:5555 shell device_config put activity_manager max_phantom_processes 2147483647 >/dev/null 2>&1 && echo "max_phantom=INT_MAX OK"
echo "--- 3. reinicio limpio de la sesion (restart49 parcheado mata restos flashback) ---"
bash "$PREFIX/bin/gnome49" --restart >/dev/null 2>&1
RC=$?
echo "gnome49_restart_exit=$RC"
echo "--- 4. salud del escritorio nuevo ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
export DISPLAY=:0
id=$(xprop -root -notype _NET_SUPPORTING_WM_CHECK 2>/dev/null | sed -n "s/.*# //p")
[ -n "$id" ] && echo "WM_REAL=$(xprop -id "$id" -notype _NET_WM_NAME 2>/dev/null | sed "s/.*= //")" || echo "WM_REAL: sin WM"
scrot -o /tmp/rt-dex/a70-escritorio.png >/dev/null 2>&1
echo "colores=$(identify -format %k /tmp/rt-dex/a70-escritorio.png 2>/dev/null)"'
echo "--- 5. broker nativo ---"
pgrep -f app-broker-termux >/dev/null && echo "BROKER_VIVO adj=$(cat /proc/$(pgrep -f app-broker-termux | head -1)/oom_score_adj)" || { setsid nohup bash ~/substrate/bridge/app-broker-termux.sh >> ~/substrate/bridge/broker.log 2>&1 & sleep 1; pgrep -f app-broker-termux >/dev/null && echo "BROKER_RELANZADO adj=$(cat /proc/$(pgrep -f app-broker-termux | head -1)/oom_score_adj)" || echo BROKER_MUERTO; }
echo "--- 6. lanzar FilmCraft via broker (el canal del dock) ---"
T0=$(date +%s)
echo filmcraft > "$PREFIX/tmp/launch.fifo"
sleep 8
FP=$(pgrep -x filmcraft | head -1)
echo "filmcraft_pid=${FP:-NO_NACIO}"
if [ -n "$FP" ]; then
  echo "--- 7. MONITOREO 4 MINUTOS (escenario real: usa el escritorio desde Termux:X11) ---"
  for i in 1 2 3 4 5 6 7 8; do
    sleep 30
    EL=$(( $(date +%s) - T0 ))
    if kill -0 "$FP" 2>/dev/null; then
      echo "t+${EL}s VIVA adj=$(cat /proc/$FP/oom_score_adj 2>/dev/null) rss=$(grep VmRSS /proc/$FP/status 2>/dev/null | awk '{print $2}')kB"
    else
      echo "t+${EL}s MURIO — firma:"
      echo "== proot/broker =="; grep -iE "signal|terminat|exit" "$PREFIX/tmp/app-live-filmcraft.log" 2>/dev/null | tail -3
      echo "== logcat lmkd en la ventana =="; adb -s 127.0.0.1:5555 shell logcat -d -T "$T0" 2>/dev/null | grep -iE "lmkd|phantom" | tail -8
      break
    fi
  done
  kill -0 "$FP" 2>/dev/null && echo "RESULTADO: FILMCRAFT SOBREVIVIO_4MIN" || echo "RESULTADO: FILMCRAFT MURIO_DURANTE_MONITOREO"
  echo "== ultima linea de su log propio =="; tail -2 "$PREFIX/tmp/app-live-filmcraft.log" 2>/dev/null
else
  echo "== por que no nacio =="; tail -5 "$PREFIX/tmp/app-live-filmcraft.log" 2>/dev/null
fi
echo "--- 8. logcat lmkd en la ventana completa de la prueba (solo si hubo kills) ---"
adb -s 127.0.0.1:5555 shell logcat -d 2>/dev/null | grep -iE "lmkd.*kill|phantom.*kill" | grep -E "$(date +%m-%d)" | tail -6 || echo "sin kills de lmkd en logcat"
echo "--- 9. estado final ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
pgrep -f app-broker-termux >/dev/null && echo BROKER_VIVO || echo BROKER_MUERTO
echo "VEREDICTO: FILMCRAFT SOBREVIVIO_4MIN + adj estable (0 o bajo) + sin kills en logcat = caso LMKD cerrado de verdad. Si murio: la firma de logcat de la ventana dice quien y con que adj mato — siguiente frente identificado."
echo "=== MISION-A70-REINICIO-LIMPIO-PRUEBA-FILMCRAFT COMPLETE ==="
echo "### BRIDGE MARKER ###"