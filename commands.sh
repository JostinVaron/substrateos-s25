echo "=== MISION-A65-SHELL-COMPACTO — completar el levantamiento del Shell $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
echo "--- 0. esperar asentamiento extra del arranque A64 (30 s) ---"
sleep 30
cat > "$T/a65.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "== estado del shell =="
pgrep -x gnome-shell >/dev/null && echo "SHELL_VIVO pid=$(pgrep -x gnome-shell | head -1)" || echo SHELL_MUERTO
if ! pgrep -x gnome-shell >/dev/null; then
  echo "== relanzando con la receta canonica (gnome49) =="
  which gnome49 2>/dev/null && gnome49 start 2>&1 | head -4 || echo "gnome49 no accesible — relanzando directo"
  if ! pgrep -x gnome-shell >/dev/null; then
    echo "== relanzamiento directo como dexuser =="
    su -s /bin/bash dexuser -c "
      export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/home/dexuser
      export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
      setsid /usr/bin/gnome-shell --x11 --replace >/tmp/gnome-shell-relaunch.log 2>&1 &"
    sleep 15
    pgrep -x gnome-shell >/dev/null && echo "SHELL_RELanzADO_VIVO pid=$(pgrep -x gnome-shell | head -1)" || { echo "SHELL_NO_NACIO"; tail -5 /tmp/gnome-shell-relaunch.log 2>/dev/null; }
  fi
fi
echo "== verificacion final: ventanas y activa =="
wmctrl -l 2>/dev/null | head -5
ACT=$(wmctrl -l 2>/dev/null | grep -i vectorcraft | awk '{print $1}' | head -1)
[ -n "$ACT" ] && { wmctrl -i -a "$ACT" 2>/dev/null; echo "vectorcraft_activada_al_frente"; } || echo "vectorcraft_no_visible"
echo "== salud =="
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
pgrep -x vectorcraft >/dev/null && echo APP_VIVA || echo APP_MUERTA
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a65.sh 2>&1
rm -f "$T/a65.sh"
echo "--- broker ---"
pgrep -f app-broker-termux >/dev/null && echo BROKER_VIVO || echo BROKER_MUERTO
echo "VEREDICTO: si SHELL_VIVO + APP_VIVA + vectorcraft al frente, el ciclo completo esta cerrado: escritorio arriba, app visible e inmune. El usuario deberia VER la ventana de VectorCraft ahora mismo en su pantalla."
echo "=== MISION-A65-SHELL-COMPACTO COMPLETE ==="
echo "### BRIDGE MARKER ###"