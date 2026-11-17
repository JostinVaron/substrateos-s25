echo "=== MISION-A63-VERIFICACION-BROKER — verificacion completa del arbol nativo $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
echo "--- 1. broker nativo: vivo y con adj=0? ---"
BP=$(pgrep -f app-broker-termux | head -1)
if [ -n "$BP" ]; then
  echo "broker_pid=$BP adj=$(cat /proc/$BP/oom_score_adj)"
else
  echo "BROKER_MUERTO — relanzando con adj heredado del bridge (0)"
  setsid nohup bash ~/substrate/bridge/app-broker-termux.sh >> ~/substrate/bridge/broker.log 2>&1 &
  sleep 1
  BP=$(pgrep -f app-broker-termux | head -1)
  echo "broker_relanzado_pid=${BP:-FALLO} adj=$(cat /proc/$BP/oom_score_adj 2>/dev/null)"
fi
echo "--- 2. fifo compartido ---"
[ -p "$PREFIX/tmp/launch.fifo" ] && echo "fifo_OK en $PREFIX/tmp/launch.fifo" || echo "fifo_FALTA"
echo "--- 3. historial del broker ---"
tail -4 "$PREFIX/tmp/app-live.log" 2>/dev/null || echo "sin historial"
echo "--- 4. dentro del proot: cliente e iconos ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
[ -x /usr/local/bin/artcraft-broker-client ] && echo "cliente_OK" || echo "cliente_FALTA"
grep -l "broker-client" /usr/share/applications/ai.storyteller.*.desktop 2>/dev/null | wc -l | xargs -I{} echo "iconos_apuntando_al_broker={}/4"
'
echo "--- 5. prueba en vivo propia: vectorcraft via fifo, 15 s ---"
pkill -x vectorcraft 2>/dev/null
echo vectorcraft > "$PREFIX/tmp/launch.fifo"
sleep 6
AP=$(pgrep -x vectorcraft | head -1)
echo "vectorcraft_pid=${AP:-NO}"
[ -n "$AP" ] && echo "adj_de_la_app=$(cat /proc/$AP/oom_score_adj) (esperado 0) rss_kb=$(ps -o rss= -p $AP | tr -d ' ')"
if [ -n "$AP" ]; then
  DEAD=""
  for i in $(seq 1 5); do sleep 3; kill -0 $AP 2>/dev/null || { echo "MURIO_EN_$((6+i*3))s"; DEAD=si; break; }; done
  [ -z "$DEAD" ] && echo "SOBREVIVIO_15s_VERIFICACION_BRIDGE"
  pkill -x vectorcraft 2>/dev/null
else
  echo "APP_NO_NACIO — revisar ~/tmp/app-live-vectorcraft.log"
  tail -5 "$PREFIX/tmp/app-live-vectorcraft.log" 2>/dev/null
fi
echo "--- 6. broker sigue vivo ---"
pgrep -f app-broker-termux >/dev/null && echo BROKER_PERSISTE || echo BROKER_MURIO
echo "=== MISION-A63-VERIFICACION-BROKER COMPLETE ==="
echo "### BRIDGE MARKER ###"