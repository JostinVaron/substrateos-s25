echo "=== MISION-A48-ARTCRAFT-LIMPIEZA — mesa limpia para prueba de una sola instancia $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/cl.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. instancias launcher vivas ahora ---"
pgrep -x artcraft-laun >/dev/null && pgrep -x artcraft-laun | tr '\n' ' ' || echo "cero_instancias"
echo ""
echo "--- 2. cerrar las que haya (pid exacto) ---"
for P in $(pgrep -x artcraft-laun 2>/dev/null); do kill "$P" 2>/dev/null && echo "matada instancia pid=$P"; done
sleep 2
pgrep -x artcraft-laun >/dev/null && echo "AUN_HAY_INSTANCIAS" || echo "MESA_LIMPIA_CERO_INSTANCIAS"
echo "--- 3. ventana launcher en pantalla? ---"
wmctrl -l 2>/dev/null | grep -i craft || echo "sin ventanas craft"
echo "--- 4. icono del dock apunta al oficial ---"
grep "^Exec=" /usr/share/applications/artcraft-gpu.desktop
echo "--- 5. salud del escritorio ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/cl.sh 2>&1
rm -f "$T/cl.sh"
echo "VEREDICTO: si MESA_LIMPIA_CERO_INSTANCIAS, el usuario puede abrir el icono del dock y probar UNA sola instancia del launcher sin colisiones."
echo "=== MISION-A48-ARTCRAFT-LIMPIEZA COMPLETE ==="
echo "### BRIDGE MARKER ###"