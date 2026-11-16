echo "=== MISION-A34-FIREFOX-R2 — Firefox con rutas corregidas $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/ff2-in.sh" <<'EOS'
set -u
FF_DONE=""
echo "--- 1. RUTA A: firefox-esr si la SIMULACION es limpia (chequeo real) ---"
apt-get -s install firefox-esr >/tmp/ff2-sim.txt 2>&1
NINST=$(grep -c "^Inst " /tmp/ff2-sim.txt)
SNAPDEP=$(grep -ciE "snapd|systemd" /tmp/ff2-sim.txt)
echo "paquetes_a_instalar=$NINST  menciones_snapd_systemd=$SNAPDEP"
grep -E "^Inst " /tmp/ff2-sim.txt | awk '{print "  +"$2}'
if [ "$NINST" -gt 0 ] && [ "$NINST" -lt 40 ] && [ "$SNAPDEP" -eq 0 ]; then
  echo "SIMULACION_LIMPIA: instalando firefox-esr por apt..."
  apt-get install -y firefox-esr >/tmp/ff2-install.log 2>&1
  if [ $? -eq 0 ] && command -v firefox-esr >/dev/null; then
    echo "APT_OK version:"
    timeout 40 firefox-esr --version 2>&1 | head -1
    FF_DONE=esr
  else
    echo "APT_FALLO:"; tail -10 /tmp/ff2-install.log
  fi
else
  echo "SIMULACION_NO_LIMPIA — saltando a RUTA B"
fi
if [ -z "$FF_DONE" ]; then
  echo "--- 2. RUTA B: binario Mozilla con slugs multiples + diagnostico HTTP ---"
  mkdir -p /home/dexuser/Apps
  for SLUG in firefox-esr-latest firefox-latest firefox-esr; do
    for LANGV in en-US es-ES; do
      URL="https://download.mozilla.org/?product=$SLUG&os=linux-aarch64&lang=$LANGV"
      echo "probando: $SLUG/$LANGV"
      CODE=$(curl -sL --max-time 420 -w "%{http_code}" -o /tmp/ff2.tar.xz "$URL" 2>/dev/null)
      SZ=$(stat -c%s /tmp/ff2.tar.xz 2>/dev/null || echo 0)
      echo "  http=$CODE tamano=$SZ"
      if [ "$SZ" -gt 50000000 ]; then
        tar -xJf /tmp/ff2.tar.xz -C /home/dexuser/Apps/ 2>/dev/null
        if [ -x /home/dexuser/Apps/firefox/firefox ]; then
          echo "MOZILLA_OK con $SLUG/$LANGV version:"
          timeout 40 /home/dexuser/Apps/firefox/firefox --version 2>&1 | head -1
          FF_DONE=mozilla
          break 2
        fi
      fi
    done
  done
  [ -z "$FF_DONE" ] && echo "RUTA_B_FALLO: slugs agotados — ver codigos http arriba"
fi
echo "--- 3. lanzador .desktop (directiva del repo) ---"
if [ "$FF_DONE" = "esr" ]; then EXECBIN=/usr/bin/firefox-esr; fi
if [ "$FF_DONE" = "mozilla" ]; then EXECBIN=/home/dexuser/Apps/firefox/firefox; fi
if [ -n "$FF_DONE" ]; then
  mkdir -p /home/dexuser/.local/share/applications
  printf '[Desktop Entry]\nType=Application\nName=Firefox\nExec=%s\nIcon=firefox\nTerminal=false\nCategories=Network;WebBrowser;\n' "$EXECBIN" > /home/dexuser/.local/share/applications/firefox.desktop
  chmod 644 /home/dexuser/.local/share/applications/firefox.desktop
  update-desktop-database /home/dexuser/.local/share/applications 2>/dev/null || true
  echo "LANZADOR_OK Exec=$EXECBIN"
fi
echo "--- 4. estado final ---"
echo "ruta_usada=${FF_DONE:-NINGUNA}"
dpkg --audit | head -3; echo "audit_ok"
df -h / | tail -1
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/ff2-in.sh 2>&1
rm -f "$T/ff2-in.sh"
echo "VEREDICTO: ruta_usada arriba. Si esr|mozilla -> Firefox instalado y con lanzador; proximo: abrirlo en la sesion viva con verificacion visual."
echo "=== MISION-A34-FIREFOX-R2 COMPLETE ==="
echo "### BRIDGE MARKER ###"