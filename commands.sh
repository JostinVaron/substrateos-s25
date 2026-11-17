echo "=== MISION-A53-POLKIT-COMPLETO — bus sistema + polkitd + regla + prueba real $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/a53.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. apt-get update (las listas vencidas hundieron a A52) ---"
apt-get update >/tmp/aptu53.log 2>&1; echo "update_exit=$?"
tail -2 /tmp/aptu53.log | head -1
echo "--- 2. instalar polkitd (moderno) con respaldo policykit-1 (clasico) ---"
apt-get install -y polkitd >/tmp/aptp53.log 2>&1 && echo polkitd_ok || { apt-get install -y policykit-1 >>/tmp/aptp53.log 2>&1 && echo policykit1_ok || echo AMBOS_FALLAN; }
grep -iE "^E:" /tmp/aptp53.log | head -2
PD=$(find /usr/lib /usr/libexec -name polkitd -type f 2>/dev/null | head -1); echo "polkitd_bin=${PD:-NO_ENCONTRADO}"
echo "--- 3. bus de SISTEMA dbus arriba (proot no lo levanta solo) ---"
if [ -S /run/dbus/system_bus_socket ]; then echo bus_sistema_ya_existe; else
  mkdir -p /run/dbus
  dbus-daemon --system --fork --nopidfile >/tmp/dbus53.log 2>&1; sleep 1
  [ -S /run/dbus/system_bus_socket ] && echo bus_sistema_arrancado || { echo bus_sistema_FALLO; tail -3 /tmp/dbus53.log; }
fi
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
echo "--- 4. polkitd corriendo a mano (sin systemd) ---"
pgrep -x polkitd >/dev/null || { "$PD" --no-debug >/tmp/polkitd53.log 2>&1 & sleep 2; }
pgrep -x polkitd >/dev/null && echo POLKITD_VIVO || { echo POLKITD_MUERTO; tail -4 /tmp/polkitd53.log; }
echo "--- 5. regla sin-contrasena para dexuser (launcher instala como ese usuario) ---"
mkdir -p /etc/polkit-1/localauthority/50-local.d
cat > /etc/polkit-1/localauthority/50-local.d/90-artcraft.pkla <<'EOP'
[Allow artcraft installs for dexuser]
Identity=unix-user:dexuser
Action=*
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOP
echo regla_pkla_ok
echo "--- 6. propagar bus de sistema al wrapper del dock ---"
grep -q DBUS_SYSTEM_BUS_ADDRESS /usr/local/bin/artcraft-dock-launch || sed -i '2i export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket' /usr/local/bin/artcraft-dock-launch
head -3 /usr/local/bin/artcraft-dock-launch
echo "--- 7. PRUEBA REAL: pkexec como dexuser (lo mismo que hace el launcher) ---"
if command -v runuser >/dev/null; then
  runuser -u dexuser -- env DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket pkexec /usr/bin/id >/tmp/pk53.log 2>&1; EC=$?
else
  su -s /bin/bash dexuser -c "DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket pkexec /usr/bin/id" >/tmp/pk53.log 2>&1; EC=$?
fi
echo "pkexec_exit=$EC"
tail -2 /tmp/pk53.log
[ "$EC" = "0" ] && echo CURADO_127 || echo AUN_NO_CURADO
echo "--- 8. salud ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a53.sh 2>&1
rm -f "$T/a53.sh"
echo "VEREDICTO: si CURADO_127 — cerrar y reabrir el launcher, instalar la app del catalogo, y avisar. El panic de winit (TranslateCoordinates) queda documentado como causa del crash original; el wrapper seguira capturando si reaparece."
echo "=== MISION-A53-POLKIT-COMPLETO COMPLETE ==="
echo "### BRIDGE MARKER ###"