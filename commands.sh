echo "=== MISION-A32-FIREFOX-EVAL — ¿Firefox servira en este entorno? $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
G() { proot-distro login ubuntu-gnome --shared-tmp -- bash -c "$1" 2>&1; }

echo "--- 1. LA TRAMPA: ¿el paquete firefox de apt es real o pasarela a snap? ---"
G 'apt-cache policy firefox 2>/dev/null | head -8'
G 'apt-cache show firefox 2>/dev/null | grep -E "^(Package|Version|Installed-Size|Size):" | head -6'
echo "dependencias que delatan la pasarela snap:"
G 'apt-cache depends firefox 2>/dev/null | grep -iE "snap| transitional" ; echo "---"; apt-cache show firefox 2>/dev/null | grep -iE "Description-en" | head -2'

echo "--- 2. ¿snapd es usable aqui? (esperado: NO en proot) ---"
G 'snap version 2>&1 | head -3; snap list 2>&1 | head -3'

echo "--- 3. alternativas en los repos oficiales ---"
G 'apt-cache policy firefox-esr 2>/dev/null | head -5; apt-cache search firefox 2>/dev/null | grep -vE "language|locale|theme|extension" | head -8'

echo "--- 4. ruta oficial Mozilla (binario arm64 directo, sin snap ni ppa) ---"
G 'timeout 12 curl -sI https://download.mozilla.org/ 2>&1 | head -3 || echo "SIN_RED_A_MOZILLA"'

echo "--- 5. recursos: RAM y disco disponible ahora ---"
G 'free -h | head -3; df -h / | tail -1'

echo "--- 6. entorno grafico que heredaria: GTK y render ---"
G 'dpkg -l 2>/dev/null | grep -cE "ii  libgtk-4|ii  libgtk-3"; echo "librerias gtk arriba"
G 'export DISPLAY=:0; timeout 6 xdpyinfo >/dev/null 2>&1 && echo X_OK'

echo "--- 7. sintesis para decidir ruta ---"
echo "LECTURA: si seccion 1 muestra Depends: snapd o paquete transitorio, la ruta apt firefox NO SIRVE."
echo "Si firefox-esr no aparece en seccion 3, las rutas viables son: binario oficial Mozilla arm64 (seccion 4) o PPA mozillateam."
echo "Firefox es GTK3 (no GTK4): riesgo LRZ/SIGKILL bajo, pero render sera software por diseno — aceptable para navegador."
echo "=== MISION-A32-FIREFOX-EVAL COMPLETE ==="
echo "### BRIDGE MARKER ###"