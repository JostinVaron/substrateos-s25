echo "=== MISION-A66-SESSION-BUS-HUNT — encontrar el bus de la sesion nueva y levantar el Shell $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
echo "--- 1. log completo del arranque (que paso en la sesion relanzada) ---"
tail -25 "$T/a64-arranque.log" 2>/dev/null || echo "log no encontrado"
echo "--- 2. donde quedo el bus de sesion? ---"
echo "== lado Termux (tmp compartido) =="
find "$T" -name "*session-bus*" -o -name "*.addr" 2>/dev/null | head -5
ls -la "$T/rt-dex" 2>/dev/null | head -5 || echo "sin $T/rt-dex"
echo "== lado proot (tmp privado del contenedor) =="
proot-distro login ubuntu-gnome -- bash -c 'find /tmp -name "*session-bus*" -o -name "*.addr" 2>/dev/null | head -5; ls -la /tmp/rt-dex/ 2>/dev/null | head -8'
echo "--- 3. procesos gnome/dbus vivos ---"
pgrep -af "gnome-shell|dbus-daemon|session-inner|session49" 2>/dev/null | head -8 || echo "ninguno visible desde Termux"
echo "--- 4. relanzamiento del Shell con el bus correcto (buscando la dir en ambos lados) ---"
cat > "$T/a66.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
ADDR=""
for F in /tmp/rt-dex/session-bus.addr /tmp/rt-dex/bus /tmp/session-bus.addr; do
  [ -s "$F" ] && { ADDR=$(cat "$F"); echo "bus_encontrado_en=$F"; break; }
done
[ -z "$ADDR" ] && { echo "BUS_NO_ENCONTRADO — enumerando candidatos"; ls /tmp/ 2>/dev/null | head -10; }
if [ -n "$ADDR" ]; then
  echo "bus_addr=$ADDR"
  DBUS_SESSION_BUS_ADDRESS="$ADDR" dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply / org.freedesktop.DBus.ListNames >/dev/null 2>&1 && echo "BUS_RESPONDE" || echo "BUS_NO_RESPONDE"
  pgrep -x gnome-shell >/dev/null || {
    echo "relanzando gnome-shell como dexuser con este bus..."
    su -s /bin/bash dexuser -c "
      export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/home/dexuser
      export DBUS_SESSION_BUS_ADDRESS='$ADDR'
      setsid /usr/bin/gnome-shell --x11 >/tmp/shell66.log 2>&1 &"
    sleep 20
    pgrep -x gnome-shell >/dev/null && echo "SHELL_NACIO pid=$(pgrep -x gnome-shell | head -1)" || { echo "SHELL_NO_NACIO"; tail -6 /tmp/shell66.log 2>/dev/null; }
  }
fi
echo "--- 5. verificacion final ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
pgrep -x vectorcraft >/dev/null && echo APP_VIVA || echo APP_MUERTA
wmctrl -l 2>/dev/null | head -5
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a66.sh 2>&1
rm -f "$T/a66.sh"
echo "--- 6. broker ---"
pgrep -f app-broker-termux >/dev/null && echo BROKER_VIVO || echo BROKER_MUERTO
echo "VEREDICTO: con el bus correcto el Shell deberia nacer. Si BUS_NO_ENCONTRADO en ambos lados, la sesion de arranque nunca completo su dbus — el siguiente paso sera relanzar todo con el script canonico del usuario en Termux (bash ~/arranque-escritorio.sh) y capturar su salida completa."
echo "=== MISION-A66-SESSION-BUS-HUNT COMPLETE ==="
echo "### BRIDGE MARKER ###"