echo "=== MISION-A38-VSCODE-DIAG — por que no arranco + parche al icono real $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/vsdiag.sh" <<'EOS'
set -u
echo "--- 1. ¿sobrevivio el intento de A37? (procesos electron/code vivos) ---"
pgrep -a -f "vscode-proot|/usr/bin/code|electron" 2>/dev/null | head -5 || echo "ningun proceso code vivo"
echo "--- 2. log completo del intento de A37 ---"
echo "[contenido vscode-live.log]:"; cat /tmp/vscode-live.log 2>/dev/null | head -20
echo "[fin log; bytes=$(stat -c%s /tmp/vscode-live.log 2>/dev/null || echo 0)]"
echo "--- 3. donde vive REALMENTE el icono del dock ---"
dpkg -L code 2>/dev/null | grep -E "desktop$" 
ls /usr/share/applications/ 2>/dev/null | grep -i code
echo "--- 4. parchear todos los .desktop de code que existan (respaldo previo) ---"
for D in $(dpkg -L code 2>/dev/null | grep -E "desktop$" | grep -v bak); do
  [ -f "$D" ] || continue
  cp -n "$D" "$D.bak-bridge" 2>/dev/null
  sed -i 's|^Exec=[^/]*code|Exec=/usr/local/bin/vscode-proot|' "$D"
  echo "parcheado: $D"; grep "^Exec=" "$D"
done
update-desktop-database /usr/share/applications 2>/dev/null || true
echo "FIN_DIAG_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/vsdiag.sh 2>&1
rm -f "$T/vsdiag.sh"
echo "--- 5. relanzamiento con paciencia (hasta 180 s) y deteccion case-insensitive ---"
setsid nohup proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root; export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null); exec /usr/local/bin/vscode-proot' > "$PREFIX/tmp/vscode-live2.log" 2>&1 &
echo "login_persistente_pid=$!"
VW=""
for i in $(seq 1 90); do
  sleep 2
  VW=$(proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'export DISPLAY=:0; xdotool search --class -i -r "code" 2>/dev/null | while read w; do n=$(xdotool getwindowname "$w" 2>/dev/null); case "$n" in *Visual*|"Code"|"code"|"Visual Studio Code"*) echo "$w"; break;; esac; done; true' 2>/dev/null | head -1)
  [ -n "$VW" ] && { echo "ventana VS Code a los ~$((i*2)) s (id=$VW)"; break; }
done
echo "--- 6. verificacion final ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c "
export DISPLAY=:0
wmctrl -l 2>/dev/null
[ -n \"$VW\" ] && { xdotool windowactivate $VW 2>/dev/null && echo VSCODE_TRAIDO_AL_FRENTE; echo \"titulo: \$(xdotool getwindowname $VW 2>/dev/null)\"; }
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
"
echo "--- 7. log del relanzamiento ---"
tail -10 "$PREFIX/tmp/vscode-live2.log" 2>/dev/null
if [ -n "$VW" ]; then
  echo "VEREDICTO: VSCODE_ABIERTO — verificar con ojos humanos, NO exito hasta confirmacion del dueno."
else
  echo "VEREDICTO: AUN_NO_ARRANCA — el porque esta en secciones 1-2 y 7; NO especular, leer."
fi
echo "=== MISION-A38-VSCODE-DIAG COMPLETE ==="
echo "### BRIDGE MARKER ###"