#!/bin/bash
# test-visibilidad.sh - Gate OBLIGATORIO de visibilidad de ventanas.
#
# PROBLEMA QUE RESUELVE: contar colores de la region de una ventana es un
# FALSO POSITIVO: el wallpaper detrás tiene miles de colores y una ventana
# "invisible" (no compuesta) parece "pintada". Este script compara PIXEL A
# PIXEL el contenido real de la ventana (XGetImage al window) contra la region
# correspondiente de la pantalla (scrot). RMSE=0 => ventana visible exacta.
#
# Uso (dentro del proot, con X :0 vivo):
#   test-visibilidad.sh <comando-de-app> [args-de-la-app...]
#   VIS_WAIT=6 test-visibilidad.sh xlogo -geometry 250x250+120+120
#
# Salida: WID, geometria, RMSE y AE. Criterio:
#   RMSE 0            -> VISIBLE pixel-exacta
#   RMSE > 0.02       -> NO compuesta / parcial => revisar COGL_DISABLE_TFP / TFP/DRI3
#
# Requiere: image-magick (import/compare/convert), x11-utils, wmctrl, x11-apps.
set -u
APP="${1:?falta comando de app}"; shift
WAIT="${VIS_WAIT:-4}"

export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/rt-dex}"

# 1) lanzar app con los argumentos que sigan
nohup setsid "$APP" "$@" >/tmp/rt-dex/test-visibilidad-app.log 2>&1 &
sleep "$WAIT"

# 2) ultima ventana del client list
WID=$(xprop -root -notype _NET_CLIENT_LIST 2>/dev/null | grep -oE '0x[0-9a-f]+' | tail -1)
if [ -z "$WID" ]; then echo "FALLO: no hay ventana mapeada"; exit 2; fi

X=$(xwininfo -id "$WID" | awk '/Absolute upper-left X/{print $4}')
Y=$(xwininfo -id "$WID" | awk '/Absolute upper-left Y/{print $4}')
W=$(xwininfo -id "$WID" | awk '/^  Width:/{print $2}')
H=$(xwininfo -id "$WID" | awk '/^  Height:/{print $2}')

# 3) contenido ventana vs pantalla
import -window "$WID" /tmp/rt-dex/tv-win.png 2>/dev/null
scrot -o /tmp/rt-dex/tv-screen.png
convert /tmp/rt-dex/tv-screen.png -crop "${W}x${H}+${X}+${Y}" +repage /tmp/rt-dex/tv-region.png
RMSE=$(compare -metric RMSE /tmp/rt-dex/tv-win.png /tmp/rt-dex/tv-region.png null: 2>&1)
AE=$(compare -metric AE -fuzz 2% /tmp/rt-dex/tv-win.png /tmp/rt-dex/tv-region.png null: 2>&1)

echo "WID=$WID geo=${W}x${H}+${X}+${Y}"
echo "RMSE=$RMSE"
echo "AE=$AE de $((W*H))"
case "$RMSE" in
  0\ \(0\)|0)  echo "VEREDICTO: VISIBLE"; exit 0 ;;
  *)           echo "VEREDICTO: SOSPECHOSA (posible TFP/DRI3 roto)"; exit 1 ;;
esac
