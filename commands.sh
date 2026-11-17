echo "=== MISION-A64-VENTANA-FANTASMA — revivir escritorio y traer ventanas al frente $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
echo "--- 0. X server vivo? ---"
ls "$T/.X11-unix" 2>/dev/null | head -2
echo "--- 1. relanzar el escritorio (idempotente) ---"
bash ~/arranque-escritorio.sh > "$T/a64-arranque.log" 2>&1 &
ARR=$!
echo "arranque_pid=$ARR"
echo "--- 2. esperar asentamiento de la sesion (50 s) ---"
sleep 50
tail -4 "$T/a64-arranque.log"
cat > "$T/a64.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "== escritorios (el * es el actual) =="
wmctrl -d
echo "== ventanas con geometria: id escritorio x y ancho alto host titulo =="
wmctrl -lG
echo "== apps vivas dentro del proot (prueba de vida real) =="
for P in vectorcraft photocraft filmcraft lightcraft artcraft-launcher; do
  pgrep -x "$P" >/dev/null 2>&1 && echo "$P VIVO pid=$(pgrep -x $P | head -1)"
done
echo "== trayendo cada ventana craft al escritorio 0 y activandola =="
wmctrl -l | grep -iE "craft" | awk '{print $1}' | while read ID; do
  wmctrl -i -r "$ID" -t 0 2>/dev/null && echo "ventana $ID movida a escritorio 0"
  wmctrl -i -a "$ID" 2>/dev/null && echo "ventana $ID activada"
done
echo "== ventanas despues del movimiento =="
wmctrl -lG
echo "== salud =="
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a64.sh 2>&1
rm -f "$T/a64.sh"
echo "--- 3. broker nativo sigue vivo? ---"
pgrep -f app-broker-termux >/dev/null && echo BROKER_VIVO || { setsid nohup bash ~/substrate/bridge/app-broker-termux.sh >> ~/substrate/bridge/broker.log 2>&1 & sleep 1; pgrep -f app-broker-termux >/dev/null && echo BROKER_RELANZADO || echo BROKER_MUERTO; }
echo "VEREDICTO: con wmctrl -lG veremos en que escritorio y con que geometria abrio la ventana fantasma. Si estaba en escritorio !=0 o con x/y fuera de pantalla, ya quedo movida y activada — el usuario deberia VER la ventana ahora. Si alguna app no aparece en 'vivas', la lista acorta el siguiente paso."
echo "=== MISION-A64-VENTANA-FANTASMA COMPLETE ==="
echo "### BRIDGE MARKER ###"