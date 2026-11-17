echo "=== MISION-A52-INSTALLER-127 — forense y cura del error 127 $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/a52.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 0. A51: vivo, muerto o colgado + limpieza de restos ---"
pgrep -f "fore.sh" >/dev/null && echo A51_VIVO || echo A51_NO_CORRE
for P in $(pgrep -f "python3 -c" 2>/dev/null); do kill -9 "$P" 2>/dev/null; echo "alloc_limpiado_pid=$P"; done
free -m | head -2
echo "--- 1. que comando de instalador busca el launcher (127 = command not found) ---"
for CMD in pkexec pkcon apt-get dpkg flatpak gdebi; do
  W=$(command -v $CMD 2>/dev/null); echo "$CMD => ${W:-FALTA}"
done
echo "strings_installer_hints:"
strings /usr/local/bin/artcraft-launcher 2>/dev/null | grep -oE "pkexec|pkcon|packagekit|apt-get|dpkg -i|flatpak install|gdebi|polkit" | sort | uniq -c | sort -rn | head -6
echo "--- 2. toolkit (paso que A51 no llego a reportar) ---"
strings /usr/local/bin/artcraft-launcher 2>/dev/null | grep -im1 -E "winit|iced-|egui|slint|libgtk|gtk-3|gtk4"
ldd /usr/local/bin/artcraft-launcher 2>&1 | grep -iE "gtk|adw" | head -4
echo "--- 3. logs del usuario (incluye tu error 127 capturado) ---"
for L in $(ls -t /tmp/artcraft-session-*.log 2>/dev/null | head -3); do
  echo "== $L =="; grep -vE "ureq_proto" "$L" | tail -6
done
echo "--- 4. LA CURA: instalar policykit + packagekit ---"
apt-get install -y policykit-1 packagekit >/tmp/apt52.log 2>&1; echo "apt_exit=$?"
grep -iE "^E:|unable|not found" /tmp/apt52.log | head -3
W=$(command -v pkcon); echo "pkcon_ahora=${W:-SIGUE_FALTA}"
echo "--- 5. agente polkit vivo en el bus de sesion ---"
if [ -x /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 ]; then
  /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1 &
  sleep 1; echo agente_gnome_ok
elif command -v lxpolkit >/dev/null 2>&1; then
  lxpolkit >/dev/null 2>&1 & sleep 1; echo lxpolkit_ok
else
  echo SIN_AGENTE_POLKIT
fi
echo "--- 6. prueba REAL del mecanismo (paquete inofensivo 'sl') ---"
timeout 150 pkcon -p --noninteractive install sl >/tmp/pkcon-test.log 2>&1; EC=$?
echo "pkcon_exit=$EC"
tail -3 /tmp/pkcon-test.log
dpkg -l sl >/dev/null 2>&1 && echo MECANISMO_INSTALACION_OK || echo MECANISMO_FALLA
echo "--- 7. salud ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a52.sh 2>&1
rm -f "$T/a52.sh"
echo "VEREDICTO: si strings muestra pkcon/pkexec y ahora existen + prueba sl OK, el 127 esta curado. PROXIMO PASO HUMANO: reintentar instalar la app desde el launcher (cerrarlo y reabrirlo primero) y avisar."
echo "=== MISION-A52-INSTALLER-127 COMPLETE ==="
echo "### BRIDGE MARKER ###"