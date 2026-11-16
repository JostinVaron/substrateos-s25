echo "=== MISION-A33-FIREFOX-INSTALL — Firefox por la ruta VIABLE $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/ff-in.sh" <<'EOS'
set -u
FF_DONE=""
echo "--- 1. decision de ruta: origen y simulacion de firefox-esr ---"
SRCUBU=$(apt-cache policy firefox-esr 2>/dev/null | grep -c "ports.ubuntu.com")
apt-get -s install firefox-esr >/tmp/ff-sim.txt 2>&1
NINST=$(grep -c "^Inst " /tmp/ff-sim.txt)
echo "origen_ubuntu=$SRCUBU  paquetes_a_instalar=$NINST"
grep -E "^Inst " /tmp/ff-sim.txt | awk '{print "  +"$2}' | head -12
if [ "$SRCUBU" -ge 1 ] && [ "$NINST" -gt 0 ] && [ "$NINST" -lt 30 ]; then
  echo "--- 2. RUTA A: apt install firefox-esr ---"
  apt-get install -y firefox-esr >/tmp/ff-install.log 2>&1
  if [ $? -eq 0 ] && command -v firefox-esr >/dev/null; then
    echo "APT_OK"
    timeout 40 firefox-esr --version 2>&1 | head -1
    FF_DONE=esr
  else
    echo "APT_FALLO:"; tail -8 /tmp/ff-install.log
  fi
else
  echo "--- esr no elegible (origen=$SRCUBU inst=$NINST); ire a RUTA B ---"
fi
if [ -z "$FF_DONE" ]; then
  echo "--- 2b. RUTA B: binario oficial Mozilla linux-aarch64 ---"
  mkdir -p /home/dexuser/Apps
  curl -sL --max-time 480 -o /tmp/ff.tar.xz "https://download.mozilla.org/?product=firefox-latest&os=linux-aarch64&lang=es-ES" || curl -sL --max-time 480 -o /tmp/ff.tar.xz "https://download.mozilla.org/?product=firefox-latest&os=linux-aarch64&lang=en-US"
  SZ=$(stat -c%s /tmp/ff.tar.xz 2>/dev/null || echo 0)
  echo "tamano_descargado=$SZ bytes"
  if [ "$SZ" -gt 50000000 ]; then
    tar -xJf /tmp/ff.tar.xz -C /home/dexuser/Apps/ && echo "EXTRACT_OK"
    if [ -x /home/dexuser/Apps/firefox/firefox ]; then
      echo "MOZILLA_OK"
      timeout 40 /home/dexuser/Apps/firefox/firefox --version 2>&1 | head -1
      FF_DONE=mozilla
    fi
  else
    echo "DESCARGA_FALLO"
  fi
fi
echo "--- 3. lanzador .desktop (directiva del repo) ---"
if [ "$FF_DONE" = "esr" ]; then
  EXECBIN=/usr/bin/firefox-esr
elif [ "$FF_DONE" = "mozilla" ]; then
  EXECBIN=/home/dexuser/Apps/firefox/firefox
fi
if [ -n "$FF_DONE" ]; then
  mkdir -p /home/dexuser/.local/share/applications
  cat > /home/dexuser/.local/share/applications/firefox.desktop <<EOD
[Desktop Entry]
Type=Application
Name=Firefox
Exec=$EXECBIN
Icon=firefox
Terminal=false
Categories=Network;WebBrowser;
EOD
  chmod 644 /home/dexuser/.local/share/applications/firefox.desktop
  chown dexuser:dexuser /home/dexuser/.local/share/applications/firefox.desktop 2>/dev/null || true
  update-desktop-database /home/dexuser/.local/share/applications 2>/dev/null || true
  echo "LANZADOR_OK Exec=$EXECBIN"
fi
echo "--- 4. estado final ---"
echo "ruta_usada=${FF_DONE:-NINGUNA}"
df -h / | tail -1
free -h | head -2
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/ff-in.sh 2>&1
rm -f "$T/ff-in.sh"
echo "VEREDICTO: ver arriba — Firefox instalado via RUTA_A (apt esr) o RUTA_B (binario Mozilla) o fallo documentado. El paquete trampa 'firefox' (PreDepends snapd) NO se toco. Siguiente paso: test de lanzamiento en la sesion viva."
echo "=== MISION-A33-FIREFOX-INSTALL COMPLETE ==="
echo "### BRIDGE MARKER ###"