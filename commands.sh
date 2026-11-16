echo "=== MISION-A45-ARTCRAFT-RECON — mapear la suite ArtCraft real, sin instalar nada $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/recon.sh" <<'EOS'
set -u
echo "--- 1. ¿existe binario artcraft en PATH? ---"
command -v artcraft 2>/dev/null || echo "no_en_path"
echo "--- 2. paquetes con 'art' o 'craft' instalados ---"
dpkg -l 2>/dev/null | grep -iE "artcraft|art-craft|artcraft" | head -10 || echo "sin_paquete"
echo "--- 3. busqueda de archivos en el sistema (60 s max) ---"
timeout 60 find / -iname "*artcraft*" -not -path "*/proc/*" -not -path "*/sys/*" 2>/dev/null | head -30
echo "--- 4. .desktop relacionados ---"
grep -il "artcraft" /usr/share/applications/*.desktop /home/dexuser/.local/share/applications/*.desktop /root/.local/share/applications/*.desktop 2>/dev/null
for D in $(grep -il "artcraft" /usr/share/applications/*.desktop 2>/dev/null | head -5); do
  echo "== $D =="; grep -E "^(Exec|Name|Icon)=" "$D"
done
echo "--- 5. directorios de datos del usuario ---"
ls -la /home/dexuser 2>/dev/null | head -20
ls -la /root 2>/dev/null | grep -iE "art|craft|config" | head -10
ls /opt 2>/dev/null
echo "--- 6. ayuda/version de binarios hallados (solo lectura, no GUI) ---"
B=$(timeout 60 find / -iname "*artcraft*" -type f -perm -u+x -not -path "*/proc/*" -not -path "*/sys/*" 2>/dev/null | head -5)
for X in $B; do
  echo "== $X =="
  timeout 15 "$X" --help 2>&1 | head -12
  timeout 10 "$X" --version 2>&1 | head -3
done
echo "--- 7. logs recientes del updater (busca 'updates are complete') ---"
timeout 30 grep -ril "updates are complete" /tmp /root/.local /home/dexuser/.local /var/log 2>/dev/null | head -5
echo "--- 8. parchar leak de zenity en artcraft-launcher (timeout 60) ---"
sed -i 's|zenity --info --title="ArtCraft Launcher"|timeout 60 zenity --info --title="ArtCraft Launcher"|' /usr/local/bin/artcraft-launcher 2>/dev/null
grep -n "zenity" /usr/local/bin/artcraft-launcher | head -2
echo "FIN_RECON"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/recon.sh 2>&1
rm -f "$T/recon.sh"
echo "VEREDICTO: mapa de la suite arriba. NO se instalo nada ni se lanzo GUI. Con estos datos se decide: binario correcto del launcher clasico y como abrirlo con substrate-gpu-run."
echo "=== MISION-A45-ARTCRAFT-RECON COMPLETE ==="
echo "### BRIDGE MARKER ###"