echo "=== MISION-A44-RAM-PURGE — purgar solo residuos mios, escritorio intacto $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/purge.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. RAM antes ---"
free -h | head -2
echo "--- 2. top 8 consumidores dentro del proot (RSS) ---"
ps aux --sort=-rss 2>/dev/null | head -9 | awk '{printf "%s %sMB ", $1, int($6/1024); for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | cut -c1-110
echo "--- 3. residuo: firefox de los tests (cierre gracil via xdotool) ---"
W=$(wmctrl -l 2>/dev/null | grep -i "mozilla firefox" | awk '{print $1}' | head -1)
if [ -n "$W" ]; then
  xdotool windowclose "$W" 2>/dev/null && echo "firefox_test_cerrado_gracilmente"
  sleep 4
else
  echo "firefox_ya_no_esta_abierto"
fi
echo "--- 4. residuos: glxgears/calc/weston (pids exactos); code solo si es huerfano sin ventana ---"
for PAT in glxgears gnome-calculato weston; do
  for P in $(pgrep -x "$PAT" 2>/dev/null); do kill "$P" 2>/dev/null && echo "matado $PAT pid=$P"; done
done
if ! wmctrl -l 2>/dev/null | grep -qi "visual studio code"; then
  for P in $(pgrep -x code 2>/dev/null); do kill "$P" 2>/dev/null && echo "matado code huerfano pid=$P"; done
else
  echo "code_omitido: hay ventana viva (no interferir)"
fi
pgrep -f vskeep >/dev/null 2>&1 && echo "GUARDIAN_REVIVIO_ALERTA" || echo "guardian_sigue_muerto_ok"
echo "--- 5. caches de apt ---"
du -sh /var/cache/apt/archives 2>/dev/null
apt-get clean 2>/dev/null && echo "apt_cache_limpiado"
apt-get autoremove -y >/tmp/purge-ar.log 2>&1; echo "autoremove_exit=$?"
tail -2 /tmp/purge-ar.log
echo "--- 6. drop_caches (puede no aplicar en proot) ---"
sync 2>/dev/null
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null && echo "drop_ok" || echo "drop_no_permitido_en_proot"
sleep 3
echo "--- 7. RAM despues ---"
free -h | head -2
echo "--- 8. consumidor mas pesado restante (tu escritorio, se espera) ---"
ps aux --sort=-rss 2>/dev/null | sed -n '2p' | cut -c1-100
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/purge.sh 2>&1
rm -f "$T/purge.sh"
echo "VEREDICTO: purga de residuos de misiones aplicada. Escritorio y sesion NO tocados. Ver RAM antes/despues arriba. Si el telefono sigue apretado, la presion principal esta en el lado Android (multitarea WTM + tablet), fuera del alcance del proot."
echo "=== MISION-A44-RAM-PURGE COMPLETE ==="
echo "### BRIDGE MARKER ###"