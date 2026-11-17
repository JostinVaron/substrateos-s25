echo "### MISION-A61-FUERA-DEL-PROOT — launcher nativo de Termux $(date -u +%FT%TZ) ###"
termux-wake-lock 2>/dev/null
cat > ~/substrate/bridge/app-broker-termux.sh <<'EOS'
#!/data/data/com.termux/files/usr/bin/bash
# Broker FUERA del proot: nace del loop del bridge (adj=0) y sus hijos heredan adj=0.
# Lanza las apps via proot-distro exec — mismo mecanismo que el propio bridge (que SI sobrevive).
set -u
WORK="$HOME/substrate/bridge"
FIFO="$WORK/launch.fifo"
mkdir -p "$WORK"
[ -p "$FIFO" ] || mkfifo "$FIFO"
while read APP < "$FIFO"; do
  [ -z "$APP" ] || [ "$APP" = "" ] && continue
  case "$APP" in
    vectorcraft|photocraft|filmcraft|lightcraft)
      LOGF="/tmp/rt-dex-shared/app-session-$(date -u +%Y%m%dT%H%M%SZ).log"
      proot-distro login ubuntu-gnome --shared-tmp -- bash -c "
        export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/home/dexuser
        export DBUS_SESSION_BUS_ADDRESS=\$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
        exec /usr/local/bin/substrate-gpu-run /usr/bin/$APP" > "$PREFIX/tmp/app-live.log" 2>&1 &
      echo "[broker-termux $(date +%H:%M:%S)] lanzando $APP (pid hijo adj=$(cat /proc/\$!/oom_score_adj 2>/dev/null))" >> "$WORK/broker.log"
      ;;
    *) echo "app_no_reconocida: $APP" >> "$WORK/broker.log" ;;
  esac
done
EOS
chmod 755 ~/substrate/bridge/app-broker-termux.sh
cat > ~/substrate/bridge/app-client-termux.sh <<'EOS'
#!/data/data/com.termux/files/usr/bin/bash
# Cliente nativo de Termux: el .desktop lo invoca DENTRO del proot...
# ...pero eso heredaria adj. En su lugar escribe al fifo compartido via --shared-tmp.
WORK="$HOME/substrate/bridge"
printf "%s\n" "$1" > "$WORK/launch.fifo" 2>/dev/null && exit 0
exit 1
EOS
chmod 755 ~/substrate/bridge/app-client-termux.sh
pkill -f app-broker-termux 2>/dev/null
setsid nohup bash ~/substrate/bridge/app-broker-termux.sh >> ~/substrate/bridge/broker.log 2>&1 &
sleep 1
pgrep -f app-broker-termux >/dev/null && echo "broker_nativo_VIVO adj=$(cat /proc/$(pgrep -f app-broker-termux | head -1)/oom_score_adj)" || echo "broker_nativo_MUERTO"
echo "--- probando el arbol completo: cliente -> fifo -> broker -> proot-distro exec -> vectorcraft ---"
bash ~/substrate/bridge/app-client-termux.sh vectorcraft
sleep 5
AP=$(pgrep -x vectorcraft | head -1)
echo "vectorcraft_pid=${AP:-NO}" 
[ -n "$AP" ] && echo "adj_de_la_app=$(cat /proc/$AP/oom_score_adj)" && echo "RSS=$(ps -o rss= -p $AP | tr -d ' ')"
sleep 10
if kill -0 ${AP:-99999} 2>/dev/null; then echo "SOBREVIVIO_15s_VIA_BROKER_NATIVO"; else echo "MURIO_AUN_CON_BROKER_NATIVO"; fi
pkill -x vectorcraft 2>/dev/null
echo "--- broker sigue vivo para el usuario ---"
pgrep -f app-broker-termux >/dev/null && echo BROKER_PERSISTE || echo BROKER_MURIO_REINICIAR
echo "### FIN MISION-A61 ###"