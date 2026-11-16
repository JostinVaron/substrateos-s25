echo "=== MISION-A37-VSCODE-FIX — diagnosticar, CURAR y abrir VS Code en vivo $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/vsfix.sh" <<'EOS'
set -u
echo "--- 1a. reproducir el fallo del dock: code como root sin flags ---"
timeout 20 code --version 2>&1 | head -2
echo "--- 1b. la cura: flags completos que Electron exige a root en proot ---"
mkdir -p /root/.config/Code-proot
V=$(timeout 40 code --no-sandbox --user-data-dir=/root/.config/Code-proot --disable-gpu --disable-dev-shm-usage --version 2>&1 | tail -1)
echo "version_con_cura=$V"
echo "--- 1c. wrapper permanente /usr/local/bin/vscode-proot ---"
printf '#!/bin/sh\nexec /usr/bin/code --no-sandbox --user-data-dir=/root/.config/Code-proot --disable-gpu --disable-dev-shm-usage "$@"\n' > /usr/local/bin/vscode-proot
chmod 755 /usr/local/bin/vscode-proot
echo "wrapper_creado"
echo "--- 1d. parchar el icono del dock (code.desktop del paquete, respaldo previo) ---"
if [ -f /usr/share/applications/code.desktop ]; then
  cp -n /usr/share/applications/code.desktop /usr/share/applications/code.desktop.bak-bridge
  sed -i 's|^Exec=.*|Exec=/usr/local/bin/vscode-proot %F|' /usr/share/applications/code.desktop
  echo "lineas_Exec_parchadas:"
  grep "^Exec=" /usr/share/applications/code.desktop
else
  echo "code.desktop NO ENCONTRADO"
fi
update-desktop-database /usr/share/applications 2>/dev/null || true
echo "--- 1e. limpieza de residuos de tests (pids exactos, nunca pkill -f) ---"
for PAT in glxgears gnome-calculato; do
  for P in $(pgrep -x "$PAT" 2>/dev/null); do kill "$P" 2>/dev/null && echo "matado $PAT pid=$P"; done
done
echo "residuos_restantes=glx:$(pgrep -x glxgears | wc -l) calc:$(pgrep -x gnome-calculato | wc -l)"
echo "FIN_FIX"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/vsfix.sh 2>&1
rm -f "$T/vsfix.sh"
echo "--- 2. lanzamiento en sesion viva (login persistente, patron Calculadora) ---"
setsid nohup proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root; export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null); exec /usr/local/bin/vscode-proot' > "$PREFIX/tmp/vscode-live.log" 2>&1 &
echo "login_persistente_pid=$!"
echo "--- 3. esperando ventana (max 60 s; Electron tarda en primer arranque) ---"
VW=""
for i in $(seq 1 30); do
  sleep 2
  VW=$(proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'export DISPLAY=:0; xdotool search --class "code" 2>/dev/null | head -1' 2>/dev/null)
  [ -n "$VW" ] && { echo "ventana VS Code detectada a los ~$((i*2)) s (id=$VW)"; break; }
done
echo "--- 4. verificacion (instrumentos, no promesas) ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c "
export DISPLAY=:0
echo 'ventanas:'; wmctrl -l 2>/dev/null
if [ -n \"$VW\" ]; then
  xdotool windowactivate $VW 2>/dev/null && echo VSCODE_TRAIDO_AL_FRENTE
  echo \"titulo: \$(xdotool getwindowname $VW 2>/dev/null)\"
fi
scrot -o /tmp/rt-dex/vscode-a37.png 2>/dev/null
identify -format 'colores=%k\n' /tmp/rt-dex/vscode-a37.png 2>/dev/null
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
"
echo "--- 5. log de arranque (si algo fallo, el porque esta aqui) ---"
tail -15 "$PREFIX/tmp/vscode-live.log" 2>/dev/null
if [ -n "$VW" ]; then
  echo "VEREDICTO: VSCODE_ABIERTO_EN_PANTALLA — queda abierto para verificacion humana. NO exito total hasta confirmacion del dueno."
else
  echo "VEREDICTO: VSCODE_NO_ARRANCO — leer seccion 5, no especular."
fi
echo "=== MISION-A37-VSCODE-FIX COMPLETE ==="
echo "### BRIDGE MARKER ###"