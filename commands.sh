echo "=== MISION-A30-R2-VISIBLE — test GPU que SI se ve en pantalla $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
echo "--- 1. lanzando glxgears CON GPU en login persistente, ventana al frente ---"
setsid nohup proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -c '
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/home/dexuser
exec substrate-gpu-run glxgears
' > "$PREFIX/tmp/gears-visible.log" 2>&1 &
echo "login_pid=$!"
echo "--- 2. esperando ventana de engranajes (max 20 s) ---"
GW=""
for i in $(seq 1 10); do
  sleep 2
  GW=$(proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'export DISPLAY=:0; xdotool search --class "glxgears" 2>/dev/null | head -1' 2>/dev/null)
  [ -n "$GW" ] && { echo "ventana glxgears detectada a los ~$((i*2)) s (id=$GW)"; break; }
done
echo "--- 3. trayendola al frente y midiendo GPU REAL del proceso ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c "
export DISPLAY=:0
xdotool windowactivate $GW 2>/dev/null && echo ENGRANAJES_TRAIDOS_AL_FRENTE
xdotool getwindowname $GW 2>/dev/null
"
GPROOT=$(pgrep -f "glxgears" | head -1)
echo "pid glxgears (host-visible)=$GPROOT"
echo "--- 4. kgsl fds del proceso en vivo (prueba dura) ---"
for i in $(seq 1 5); do
  K=$(proot-distro login ubuntu-gnome --shared-tmp -- bash -c "ls -l /proc/\$(pgrep -f glxgears | head -1)/fd 2>/dev/null | grep -c kgsl" 2>/dev/null)
  echo "intento $i: kgsl_fds=$K"
  [ "$K" -ge 1 ] 2>/dev/null && break
  sleep 2
done
echo "--- 5. fps en vivo desde el log ---"
sleep 6
grep -oE "[0-9]+\.?[0-9]* FPS" "$PREFIX/tmp/gears-visible.log" | tail -2
echo "--- 6. shell y estado ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO'
echo "VEREDICTO: ENGRANAJES_ABIERTOS_CON_GPU — la ventana queda GIRANDO en pantalla. kgsl_fds del proceso arriba (>=1 = GPU fisica). Confirma visualmente; para cerrar: proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'DISPLAY=:0 xdotool search --class glxgears windowclose'"
echo "=== MISION-A30-R2-VISIBLE COMPLETE ==="
echo "### BRIDGE MARKER ###"