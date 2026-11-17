echo "=== MISION-A58-CAZADOR-SIGKILL — quien dispara el SIGKILL $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/a58.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. arbol de procesos y oom_score_adj de cada nivel (la huella del asesino) ---"
echo "== Termux base (la raiz de todo) =="
for P in $(pgrep -f "com.termux" | head -2); do
  echo "pid=$P adj=$(cat /proc/$P/oom_score_adj 2>/dev/null) name=$(cat /proc/$P/cmdline 2>/dev/null | tr '\0' ' ' | cut -c1-60)"
done
echo "== proot (el contenedor) =="
for P in $(pgrep -x proot); do
  echo "pid=$P adj=$(cat /proc/$P/oom_score_adj 2>/dev/null)"
done
echo "== gnome-shell y x11 =="
for P in $(pgrep -x gnome-shell; pgrep -f termux-x11 | head -1); do
  [ -n "$P" ] && echo "pid=$P adj=$(cat /proc/$P/oom_score_adj 2>/dev/null) $(cat /proc/$P/comm 2>/dev/null)"
done
echo "--- 2. logcat: LMKD al acecho (lo que Android piensa de tus procesos) ---"
logcat -d 2>/dev/null | grep -iE "lmkd|lowmemorykiller|kill" | grep -iE "termux|proot|craft" | tail -6 || echo "logcat_vacio (normal sin root)"
echo "--- 3. PRUEBA A/B: vectorcraft CON proteccion anti-kill ---"
TS=$(date -u +%Y%m%dT%H%M%SZ)
LOG=/tmp/ab-test-$TS.log
substrate-gpu-run /usr/bin/vectorcraft > "$LOG" 2>&1 &
AP=$!
sleep 2
echo "== intento de blindaje: oom_score_adj=-1000 en todo el arbol =="
for P in $AP $(pgrep -P $AP) $(pgrep -x vectorcraft); do
  echo -1000 > /proc/$P/oom_score_adj 2>/dev/null && echo "pid=$P blindado" || echo "pid=$P NO_blindable (permiso)"
done
echo "oom_score_adj_final=$(cat /proc/$AP/oom_score_adj 2>/dev/null)"
echo "--- 4. monitoreo 45 s (sin tocar el foco — solo ver si muere espontaneamente) ---"
DEAD=""
for i in $(seq 1 15); do
  sleep 3
  kill -0 $AP 2>/dev/null || { wait $AP; RC=$?; echo "MURIO_EN_$((i*3))s EXIT=$RC"; DEAD=si; break; }
  [ $((i % 3)) -eq 0 ] && echo "t=$((i*3))s vivo rss_kb=$(ps -o rss= -p $AP 2>/dev/null | tr -d ' ')"
done
[ -z "$DEAD" ] && { echo "SOBREVIVIO_45s_BLINDADA"; kill $AP 2>/dev/null; }
echo "--- 5. firma del test ---"
grep -vE "ureq_proto|MESA|vblank" "$LOG" | tail -6
echo "--- 6. salud ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a58.sh 2>&1
rm -f "$T/a58.sh"
echo "VEREDICTO: si vectorcraft BLINDADA sobrevive y la desprotegida murio en 3s (A57), el asesino es LMKD por oom_score_adj y la cura es blindar el arbol en el wrapper de apps (una linea en artcraft-app-launch). Si la blindada TAMBIEN muere, el asesino no es LMKD sino gestion Samsung/cgroup y el frente cambia (termux-wake-lock + foreground service o mover el proot a foreground)."
echo "=== MISION-A58-CAZADOR-SIGKILL COMPLETE ==="
echo "### BRIDGE MARKER ###"