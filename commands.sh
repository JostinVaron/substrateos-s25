echo "=== MISION-A71-UN-LOOP-PRUEBA-BIEN — un solo loop + prueba de FilmCraft medida bien $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
RT="$PREFIX/tmp/rt-dex"
echo "--- 1. matar al v5 huérfano (doble loop detectado en A70) ---"
if kill -0 24468 2>/dev/null; then
  kill -9 24468 2>/dev/null && echo "V5_MATADO (pid 24468)"
else
  echo "v5_pid=24468 ya no existe"
fi
sleep 1
for L in v5 v6; do
  F="$HOME/substrate/bridge/$L.lock"
  [ -f "$F" ] && { P=$(cat "$F"); kill -0 "$P" 2>/dev/null && echo "$L: VIVO pid=$P" || echo "$L: lock viejo"; } || echo "$L: ausente"
done
echo "--- 2. escritorio: verificar desde dentro del proot ---"
FP0=$(proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'pgrep -x filmcraft | head -1' 2>/dev/null | tr -d '\r')
if [ -z "$FP0" ]; then
  echo filmcraft > "$PREFIX/tmp/launch.fifo"
  echo "lanzada via fifo del broker — esperando 12 s"
  sleep 12
  FP0=$(proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'pgrep -x filmcraft | head -1' 2>/dev/null | tr -d '\r')
fi
echo "filmcraft_pid=${FP0:-NO}"
cat > "$RT/a71.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "== WM =="
id=$(xprop -root -notype _NET_SUPPORTING_WM_CHECK 2>/dev/null | sed -n "s/.*# //p")
[ -n "$id" ] && echo "WM_REAL=$(xprop -id "$id" -notype _NET_WM_NAME 2>/dev/null | sed 's/.*= //')" || echo "WM_REAL: sin WM"
scrot -o /tmp/rt-dex/a71.png >/dev/null 2>&1
echo "colores=$(identify -format %k /tmp/rt-dex/a71.png 2>/dev/null)"
pgrep -x gnome-shell >/dev/null && echo "SHELL_VIVO pid=$(pgrep -x gnome-shell | head -1)" || echo SHELL_MUERTO
echo "== FilmCraft desde dentro =="
FP=$(pgrep -x filmcraft | head -1)
[ -n "$FP" ] && echo "filmcraft_VIVA pid=$FP adj=$(cat /proc/$FP/oom_score_adj 2>/dev/null) rss=$(grep VmRSS /proc/$FP/status | awk '{print $2}')kB" || echo "filmcraft_AUSENTE"
echo "FIN_PARTE1"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/rt-dex/a71.sh 2>&1
rm -f "$RT/a71.sh"
if [ -n "$FP0" ]; then
  echo "--- 3. MONITOREO 4 MIN (mediciones desde dentro del proot) ---"
  T0=$(date +%s); ALIVE=""
  for i in 1 2 3 4 5 6 7 8; do
    sleep 30
    EL=$(( $(date +%s) - T0 ))
    ST=$(proot-distro login ubuntu-gnome --shared-tmp -- bash -c "P=\$(pgrep -x filmcraft | head -1); [ -n \"\$P\" ] && { cat /proc/\$P/oom_score_adj; grep VmRSS /proc/\$P/status | awk '{print \$2}'; }" 2>/dev/null | tr '\r\n' ' ')
    if [ -n "$ST" ]; then echo "t+${EL}s VIVA [adj rss]=[$ST]"; ALIVE=1
    else
      echo "t+${EL}s MURIO — firma:"; grep -iE "signal|exit|terminat" "$PREFIX/tmp/app-live-filmcraft.log" 2>/dev/null | tail -3; ALIVE=""; break
    fi
  done
  [ -n "$ALIVE" ] && echo "RESULTADO: FILMCRAFT SOBREVIVIO_4MIN"
else
  echo "== por que no nacio =="; tail -6 "$PREFIX/tmp/app-live-filmcraft.log" 2>/dev/null
fi
echo "--- 4. logcat FRESCO de la ventana ---"
adb -s 127.0.0.1:5555 shell logcat -d -t 400 2>/dev/null | grep -iE "lmkd|phantom|kill.*termux|termux.*kill" | tail -8 || echo "sin actividad lmkd fresca"
echo "--- 5. estado final ---"
P6=$(cat "$HOME/substrate/bridge/v6.lock" 2>/dev/null)
kill -0 ${P6:-99999} 2>/dev/null && echo "LOOP_V6_VIVO pid=$P6 (unico)" || echo LOOP_V6_MUERTO
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO; pgrep -x filmcraft >/dev/null && echo FILMCRAFT_VIVA || echo FILMCRAFT_NO' 2>/dev/null
pgrep -f app-broker-termux >/dev/null && echo BROKER_VIVO || echo BROKER_MUERTO
echo "VEREDICTO: un solo loop + FilmCraft VIVA con adj estable tras 4 min + sin kills frescos = sistema verificado en su configuracion final y caso cerrado. Si murio, esta ventana es limpia: un solo loop y medicion interna."
echo "=== MISION-A71-UN-LOOP-PRUEBA-BIEN COMPLETE ==="
echo "### BRIDGE MARKER ###"