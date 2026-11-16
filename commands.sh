echo "=== MISION-A36-VSCODE — limpiar trampa + instalar VS Code completo $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/vs-in.sh" <<'EOS'
set -u
echo "--- 1. TRAMPA firefox: simulacion de borrado (nunca a ciegas) ---"
apt-get -s remove firefox >/tmp/rm-sim.txt 2>&1
NREM=$(grep -c "^Remv " /tmp/rm-sim.txt)
grep -E "^Remv " /tmp/rm-sim.txt | awk '{print "  -"$2}'
CRIT=$(grep -Ei "^Remv (gnome-shell|mutter|xorg|gnome-session|gnome-core|firefox-esr)" /tmp/rm-sim.txt | wc -l)
echo "paquetes_a_remover=$NREM criticos=$CRIT"
if [ "$NREM" -le 5 ] && [ "$CRIT" -eq 0 ]; then
  apt-get remove -y firefox >/tmp/rm-real.log 2>&1 && echo "TRAMPA_ELIMINADA" || { echo "REMOVE_FALLO:"; tail -5 /tmp/rm-real.log; }
else
  echo "TRAMPA_CONSERVADA — borrado tendria colateral, ver lista arriba"
fi
dpkg -l firefox 2>/dev/null | grep -c "^ii" | sed 's/^/firefox_ii_restantes=/'

echo "--- 2. repo oficial Microsoft (clave GPG + sources arm64) ---"
if [ ! -s /usr/share/keyrings/packages.microsoft.gpg ]; then
  curl -sL --max-time 150 https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/packages.microsoft.gpg 2>/dev/null || echo "GPG_FALLO"
fi
SZK=$(stat -c%s /usr/share/keyrings/packages.microsoft.gpg 2>/dev/null || echo 0)
echo "gpg_size=$SZK"
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
apt-get update >/tmp/vs-upd.log 2>&1
echo "update_exit=$?"
apt-cache policy code 2>/dev/null | head -4

echo "--- 3. instalando code ---"
apt-get install -y code >/tmp/vs-inst.log 2>&1
echo "install_exit=$?"
tail -4 /tmp/vs-inst.log
if command -v code >/dev/null; then
  echo "VERSION:"
  timeout 40 code --no-sandbox --disable-gpu --version 2>&1 | head -3
else
  echo "CODE_NO_ENCONTRADO — log completo:"
  tail -15 /tmp/vs-inst.log
fi

echo "--- 4. lanzador proot-safe (directiva del repo) ---"
if command -v code >/dev/null; then
  mkdir -p /home/dexuser/.local/share/applications
  cat > /home/dexuser/.local/share/applications/vscode-proot.desktop <<EOD2
[Desktop Entry]
Type=Application
Name=VS Code (proot-safe)
Exec=code --no-sandbox --disable-gpu %F
Icon=code
Terminal=false
Categories=Development;IDE;
StartupWMClass=code
EOD2
  chmod 644 /home/dexuser/.local/share/applications/vscode-proot.desktop
  update-desktop-database /home/dexuser/.local/share/applications 2>/dev/null || true
  echo "LANZADOR_OK (vscode-proot.desktop con flags proot)"
fi

echo "--- 5. salud final ---"
dpkg --audit | head -3; echo "audit_ok"
df -h / | tail -1
free -h | head -2
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/vs-in.sh 2>&1
rm -f "$T/vs-in.sh"
echo "VEREDICTO: ver arriba — trampa evaluada/eliminada sin colateral y VS Code arm64 oficial instalado con lanzador proot-safe. Proximo: abrirlo en la sesion viva y login GitHub para funciones agenticas (Copilot)."
echo "=== MISION-A36-VSCODE COMPLETE ==="
echo "### BRIDGE MARKER ###"