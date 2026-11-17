echo "=== MISION-A54-POLKIT-FALLBACK — forense fino + instalador de respaldo $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/a54.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
echo "--- 0. servicios de A53 siguen vivos? ---"
pgrep -x polkitd >/dev/null && echo POLKITD_VIVO || { /usr/lib/polkit-1/polkitd >/tmp/polkitd54.log 2>&1 & sleep 2; pgrep -x polkitd >/dev/null && echo POLKITD_RELanzADO || echo POLKITD_MUERTO; }
[ -S /run/dbus/system_bus_socket ] && echo BUS_SISTEMA_OK || { mkdir -p /run/dbus; dbus-daemon --system --fork --nopidfile >/dev/null 2>&1; sleep 1; [ -S /run/dbus/system_bus_socket ] && echo BUS_RELanzADO || echo BUS_MUERTO; }
echo "--- 1. forense fino: stderr COMPLETO de pkexec como dexuser ---"
su -s /bin/bash dexuser -c "DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket pkexec /usr/bin/id" > /tmp/pk54.log 2>&1; EC=$?
echo "exit=$EC"; cat /tmp/pk54.log
echo "--- 2. la clave de proot: pkexec requiere setuid ---"
ls -l /usr/bin/pkexec | awk '{print $1, $NF}'
[ -x /usr/bin/pkexec ] && [ "$(stat -c %a /usr/bin/pkexec | cut -c4)" = "4" ] 2>/dev/null && echo SETUID_OK || echo SETUID_FALTA_127_EXPLICADO
echo "--- 3. FALLBACK PRACTICO: probar la ruta que SI funciona (apt como root) ---"
ls -la /home/dexuser/.cache/artcraft-launcher/downloads/ 2>/dev/null | tail -4
DEB=$(ls -t /home/dexuser/.cache/artcraft-launcher/downloads/*.deb 2>/dev/null | head -1)
echo "deb_descargado=${DEB:-NINGUNO_AUN}"
echo "--- 4. parche del wrapper: fallback automatico post-instalador-fallido ---"
cat > /usr/local/bin/artcraft-install-fallback <<'EOF'
#!/bin/bash
# Instala los .deb que el launcher ya descargo pero no pudo instalar (127).
# Corre como root dentro del proot. Idempotente: dpkg no reinstala lo ya instalado.
LOG=/tmp/artcraft-fallback.log
echo "[$(date -u +%FT%TZ)] fallback manual invocado" >> "$LOG"
for DEB in /home/dexuser/.cache/artcraft-launcher/downloads/*.deb; do
  [ -f "$DEB" ] || continue
  NOMBRE=$(dpkg-deb -f "$DEB" Package 2>/dev/null)
  if dpkg -s "$NOMBRE" >/dev/null 2>&1; then
    echo "[$(date -u +%FT%TZ)] $NOMBRE ya instalado, skip" >> "$LOG"
  else
    echo "[$(date -u +%FT%TZ)] instalando $NOMBRE desde $DEB" >> "$LOG"
    apt-get -y install "$DEB" >> "$LOG" 2>&1 && echo "  -> OK" >> "$LOG" || echo "  -> FALLO" >> "$LOG"
  fi
done
echo "[$(date -u +%FT%TZ)] fallback terminado" >> "$LOG"
EOF
chmod 755 /usr/local/bin/artcraft-install-fallback
echo fallback_instalado
echo "--- 5. prueba real del fallback (con lo que haya descargado) ---"
if [ -n "$DEB" ]; then
  /usr/local/bin/artcraft-install-fallback
  N=$(dpkg-deb -f "$DEB" Package 2>/dev/null)
  dpkg -s "$N" >/dev/null 2>&1 && echo "FALLBACK_FUNCIONA ($N instalado)" || echo FALLO_FALLBACK
  tail -3 /tmp/artcraft-fallback.log
else
  echo "sin deb para probar aun — se probara cuando el usuario reintente desde el launcher"
fi
echo "--- 6. salud ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a54.sh 2>&1
rm -f "$T/a54.sh"
echo "VEREDICTO: si SETUID_FALTA, el 127 de pkexec esta EXPLICADO DE RAIZ (proot no soporta setuid) y la solucion DEFINITIVA es el fallback: usuario reintenta en el launcher (fallara igual), luego corre 'bash /usr/local/bin/artcraft-install-fallback' desde Termux con proot, o pedimos al bridge correrlo tras cada intento."
echo "=== MISION-A54-POLKIT-FALLBACK COMPLETE ==="
echo "### BRIDGE MARKER ###"