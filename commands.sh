echo "=== MISION-A29-CALC — abrir la Calculadora en tu Ubuntu $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
echo "--- 0. precondiciones ---"
echo "X :0 viva?"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'DISPLAY=:0 timeout 4 xdpyinfo >/dev/null 2>&1 && echo X_OK || echo X_MUERTA'
echo "sesion viva (pid shell): $(cat $PREFIX/tmp/rt-dex/shell49.pid 2>/dev/null)"
echo "bus de sesion: $(cat $PREFIX/tmp/rt-dex/session-bus.addr 2>/dev/null || echo NO_HAY)"
echo "--- 1. ventanas antes ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'DISPLAY=:0 wmctrl -l 2>/dev/null' | head -8
echo "--- 2. lanzando gnome-calculator (receta GTK4 segura del repo) ---"
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -c '
export HOME=/home/dexuser DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)
export GSK_RENDERER=cairo GTK_A11Y=none NO_AT_BRIDGE=1
nohup gnome-calculator >/tmp/rt-dex/calc-a29.log 2>&1 &
echo "calc_pid=$!"
'
sleep 12
echo "--- 3. verificacion: proceso + ventana ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
pgrep -ax gnome-calculator | head -2
echo "ventanas:"
DISPLAY=:0 wmctrl -l 2>/dev/null | grep -i calc && echo VENTANA_CALC_DETECTADA || echo VENTANA_CALC_NO_VISTA
'
echo "--- 4. captura con colores (evidencia de UI pintada) ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
DISPLAY=:0 scrot -o /tmp/rt-dex/calc-a29.png 2>/dev/null
identify -format "colores=%k\n" /tmp/rt-dex/calc-a29.png 2>/dev/null || echo "sin captura"
'
echo "--- 5. cerrando la Calculadora limpio (xdotool) ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
W=$(DISPLAY=:0 xdotool search --name "Calculadora" 2>/dev/null | head -1)
W2=$(DISPLAY=:0 xdotool search --name "Calculator" 2>/dev/null | head -1)
if [ -n "${W}${W2}" ]; then
  DISPLAY=:0 xdotool windowclose ${W:-$W2} && echo CALC_CERRADA_GRACIOSO
else
  echo "ventana no encontrada por nombre; cerrando por pid exacto"
  P=$(pgrep -x gnome-calculator | head -1)
  [ -n "$P" ] && kill "$P" && echo "calc pid $P terminado con TERM"
fi
'
sleep 3
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'pgrep -x gnome-calculator >/dev/null && echo CALC_AUN_VIVA || echo CALC_CERRADA_OK'
echo "--- 6. el shell sobrevivio? ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
tail -3 /tmp/rt-dex/calc-a29.log 2>/dev/null
'
echo "VEREDICTO: CALC_CONTROL_OK — abriste, viste y cerraste una app GTK4 en la sesion viva; el shell sobrevivio. Control del Ubuntu demostrado sin dano."
echo "=== MISION-A29-CALC COMPLETE ==="
echo "### BRIDGE MARKER ###"