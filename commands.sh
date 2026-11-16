echo "=== MISION-A46-ARTCRAFT-INSTALL — launcher OFICIAL aarch64, el correcto $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/aci.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. descubrir assets reales del release v0.19.2 via API (sin inventar) ---"
curl -s --max-time 60 https://api.github.com/repos/storytold/craft-launcher/releases/tags/v0.19.2 > /tmp/cl-rel.json
echo "assets_encontrados:"
grep -o '"name": *"[^"]*\(deb\|AppImage\|rpm\|flatpak\)[^"]*"' /tmp/cl-rel.json | sed 's/"name": *//' | sort -u | head -20
DEB_URL=$(grep -o '"browser_download_url": *"[^"]*aarch64[^"]*\.deb"' /tmp/cl-rel.json | head -1 | grep -o 'https[^"]*')
AI_URL=$(grep -o '"browser_download_url": *"[^"]*aarch64[^"]*\.AppImage"' /tmp/cl-rel.json | head -1 | grep -o 'https[^"]*')
echo "deb_aarch64=${DEB_URL:-NINGUNO}"
echo "appimage_aarch64=${AI_URL:-NINGUNO}"
if [ -n "$DEB_URL" ]; then
  echo "--- 2. descargar .deb aarch64 oficial ---"
  curl -L --max-time 600 -o /tmp/craft-launcher-aarch64.deb "$DEB_URL" && echo "descarga_ok bytes=$(stat -c%s /tmp/craft-launcher-aarch64.deb)"
  echo "--- 3. instalar (apt resuelve dependencias) ---"
  apt-get install -y /tmp/craft-launcher-aarch64.deb >/tmp/cl-inst.log 2>&1
  echo "install_exit=$?"; tail -3 /tmp/cl-inst.log
elif [ -n "$AI_URL" ]; then
  echo "--- 2b. no hay .deb aarch64 — usando AppImage aarch64 (directiva repo: extract-and-run) ---"
  curl -L --max-time 600 -o /home/dexuser/Apps/artcraft-launcher-aarch64.AppImage "$AI_URL"
  chmod +x /home/dexuser/Apps/artcraft-launcher-aarch64.AppImage
  echo "appimage_ok bytes=$(stat -c%s /home/dexuser/Apps/artcraft-launcher-aarch64.AppImage)"
else
  echo "VEREDICTO: SIN_ASSET_AARCH64_COMPATIBLE — NO invento; reportar al dueno"
  exit 0
fi
echo "--- 4. binario oficial presente? ---"
command -v artcraft-launcher && /usr/bin/artcraft-launcher --version 2>/dev/null | head -1 || ls /home/dexuser/Apps/*.AppImage 2>/dev/null
echo "--- 5. colision: renombrar MI script, no tapar al oficial ---"
[ -f /usr/local/bin/artcraft-launcher ] && mv /usr/local/bin/artcraft-launcher /usr/local/bin/artcraft-helper && echo "mi_script_renombrado_a_artcraft-helper"
echo "--- 6. repuntar icono del dock al launcher OFICIAL con GPU wrapper ---"
printf '[Desktop Entry]\nType=Application\nName=ArtCraft Launcher\nExec=substrate-gpu-run artcraft-launcher\nIcon=applications-graphics\nTerminal=false\nCategories=Graphics;\n' > /usr/share/applications/artcraft-gpu.desktop
update-desktop-database /usr/share/applications 2>/dev/null || true
grep "^Exec=" /usr/share/applications/artcraft-gpu.desktop
echo "--- 7. prueba GUI: lanzar, esperar ventana, capturar, CERRAR LIMPIO (sin residuos) ---"
nohup substrate-gpu-run artcraft-launcher > /tmp/cl-gui.log 2>&1 &
GP=$!
VW=""
for i in $(seq 1 30); do
  sleep 2
  VW=$(wmctrl -l 2>/dev/null | grep -iE "artcraft|craft" | awk '{print $1}' | head -1)
  [ -n "$VW" ] && { echo "ventana_a_los_$((i*2))s id=$VW nombre='$(xdotool getwindowname $VW 2>/dev/null)'"; break; }
done
scrot -o /tmp/rt-dex/artcraft-launcher.png 2>/dev/null
identify -format 'colores=%k\n' /tmp/rt-dex/artcraft-launcher.png 2>/dev/null
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
[ -n "$VW" ] && xdotool windowclose "$VW" 2>/dev/null && echo "ventana_cerrada_limpia"
sleep 3
head -8 /tmp/cl-gui.log
pgrep -x artcraft-laun >/dev/null && echo "LAUNCHER_PROCESO_RESTANTE (matar por pid)" && for P in $(pgrep -x artcraft-laun); do kill "$P"; done || echo "SIN_RESIDUOS"
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/aci.sh 2>&1
rm -f "$T/aci.sh"
echo "VEREDICTO: ver arriba. Si install_ok y ventana detectada: launcher oficial instalado; el usuario lo abre desde el dock cuando quiera (vive dentro de su sesion GNOME). Si SIN_ASSET: no se invento nada, reportar."
echo "=== MISION-A46-ARTCRAFT-INSTALL COMPLETE ==="
echo "### BRIDGE MARKER ###"