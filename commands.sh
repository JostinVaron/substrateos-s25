echo "=== MISION-A40-VSCODE-FRENTE — traer la ventana existente al frente $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/vsfront.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
W=$(wmctrl -l 2>/dev/null | grep -i "visual studio code" | awk '{print $1}' | head -1)
echo "ventana=$W"
if [ -n "$W" ]; then
  xdotool windowactivate "$W" 2>/dev/null && echo ACTIVADA
  xdotool windowsize "$W" 90% 90% 2>/dev/null; xdotool windowmove "$W" 5% 5% 2>/dev/null
  sleep 2
  scrot -o /tmp/rt-dex/vscode-a40.png 2>/dev/null
  identify -format 'colores=%k\n' /tmp/rt-dex/vscode-a40.png 2>/dev/null
  echo "titulo='$(xdotool getwindowname $W 2>/dev/null)'"
  echo "proceso_principal_vivo=$(pgrep -f 'code/code --no-sandbox' | head -1)"
  echo "VEREDICTO_A40: VSCODE_AL_FRENTE_Y_VISIBLE"
else
  echo "VEREDICTO_A40: VENTANA_DESAPARECIDA — relevar de nuevo"
  wmctrl -l 2>/dev/null
  pgrep -a -f "code/code" 2>/dev/null | head -3
fi
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/vsfront.sh 2>&1
rm -f "$T/vsfront.sh"
echo "=== MISION-A40-VSCODE-FRENTE COMPLETE ==="
echo "### BRIDGE MARKER ###"