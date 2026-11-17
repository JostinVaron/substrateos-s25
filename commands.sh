echo "=== MISION-A51-ARTCRAFT-FORENSE — toolkit, OOM, sw+interaccion $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/fore.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. cerrar instancias ---"
for P in $(pgrep -x artcraft-laun 2>/dev/null); do kill "$P" 2>/dev/null; done
sleep 1
pgrep -x artcraft-laun >/dev/null && echo AUN_HAY || echo CERO_INSTANCIAS
echo "--- 2. logs del wrapper (sesiones del usuario) ---"
ls -la /tmp/artcraft-session-*.log 2>/dev/null | tail -4
for L in $(ls -t /tmp/artcraft-session-*.log 2>/dev/null | head -2); do
  echo "== $L =="; grep -vE "ureq_proto" "$L" | tail -8
done
echo "--- 3. toolkit del binario (define la cura) ---"
ldd /usr/local/bin/artcraft-launcher 2>&1 | head -12
echo "hints:"
strings /usr/local/bin/artcraft-launcher 2>/dev/null | grep -im1 -E "winit|iced-|egui|slint|libgtk|gtk-3|gtk4|relm4"
echo "--- 4. flags soportados ---"
timeout 20 artcraft-launcher --help 2>&1 | head -12
echo "--- 5. dispositivos de entrada reales ---"
apt-get install -y xinput >/tmp/xi.log 2>&1
xinput list 2>&1 | head -14
echo "--- 6. lanzamiento MONITORIZADO (ruta exacta del dock) 150 s ---"
/usr/local/bin/artcraft-dock-launch &
WP=$!
for i in $(seq 1 30); do
  sleep 5
  RSS=$(ps -o rss= -p "$(pgrep -x artcraft-laun | head -1)" 2>/dev/null)
  FM=$(free -m | awk '/^Mem/{print $7}')
  echo "t=$((i*5))s rss_kb=${RSS:-MUERTO} memlibre_mb=$FM"
  pgrep -x artcraft-laun >/dev/null || { wait $WP; echo "MURIO_EXIT=$? t=$((i*5))s"; break; }
done
pgrep -x artcraft-laun >/dev/null && { echo "SOBREVIVIO_150s"; for P in $(pgrep -x artcraft-laun); do kill "$P"; done; }
echo "--- 7. test OOM: presion 3 GiB + relanzar 90 s ---"
nohup python3 -c "
import time
b=[]
try:
    while True:
        b.append(bytearray(50*1024*1024)); time.sleep(0.4)
        if sum(len(x) for x in b) >= 3*1024**3: break
except MemoryError:
    pass
time.sleep(150)
" > /tmp/alloc.log 2>&1 &
ALLOC=$!
sleep 10
free -m | head -2
/usr/local/bin/artcraft-dock-launch &
WP2=$!
for i in $(seq 1 18); do
  sleep 5
  pgrep -x artcraft-laun >/dev/null || { wait $WP2; echo "MURIO_BAJO_PRESION_EXIT=$? t=$((i*5))s"; break; }
done
pgrep -x artcraft-laun >/dev/null && echo "SOBREVIVIO_PRESION" || true
kill "$ALLOC" 2>/dev/null
for P in $(pgrep -f "python3 -c"); do kill "$P" 2>/dev/null; done
for P in $(pgrep -x artcraft-laun); do kill "$P" 2>/dev/null; done
sleep 2
free -m | head -2
echo "--- 8. software render + interaccion (hueco de matriz) ---"
HOME=/home/dexuser LIBGL_ALWAYS_SOFTWARE=1 GSK_RENDERER=cairo artcraft-launcher > /tmp/a51-sw.log 2>&1 &
SP=$!
sleep 8
VW=$(wmctrl -l 2>/dev/null | grep -i craft | awk '{print $1}' | head -1)
if [ -n "$VW" ]; then
  xdotool windowactivate "$VW" 2>/dev/null; sleep 1
  read X Y W H <<< "$(xdotool getwindowgeometry --shell $VW | awk '/^X/{x=$2}/^Y/{y=$2}/^WIDTH/{w=$2}/^HEIGHT/{h=$2} END{print x,y,w,h}')"
  CX=$((X+W/2)); CY=$((Y+H/2))
  for i in 1 2 3; do xdotool mousemove $((CX-80+i*40)) $((CY-60+i*20)); sleep 1; done
  xdotool click 1; sleep 2
  xdotool key Down; sleep 2
  xdotool click 1; sleep 3
  if kill -0 $SP 2>/dev/null; then echo "SOBREVIVIO_SW_INTERACCION"; else wait $SP; echo "CRASH_SW_INTERACCION_EXIT=$?"; fi
  grep -vE "ureq_proto" /tmp/a51-sw.log | grep -iE "panic|error|fatal" | tail -8
  for P in $(pgrep -x artcraft-laun); do kill "$P" 2>/dev/null; done
else
  echo "SIN_VENTANA_SW (posible crash de arranque sw)"; wait $SP; echo "EXIT_SW=$?"
  tail -8 /tmp/a51-sw.log | grep -vE "ureq_proto"
fi
echo "--- 9. salud ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/fore.sh 2>&1
rm -f "$T/fore.sh"
echo "VEREDICTO: con toolkit + exit codes + matriz completa arriba se decide la cura en A52. NO especular."
echo "=== MISION-A51-ARTCRAFT-FORENSE COMPLETE ==="
echo "### BRIDGE MARKER ###"