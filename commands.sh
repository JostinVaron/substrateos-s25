echo "=== MISION-A60-BROKER-BLINDADO — lanzar apps desde un padre con adj=0 $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/a60.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. firma de la muerte instantanea: el log mas reciente ---"
L=$(ls -t /tmp/app-session-*.log 2>/dev/null | head -1)
[ -n "$L" ] && { echo "== $L =="; cat "$L" | tail -10; ADJ=$(grep -oE "adj=[0-9-]+" "$L" | tail -1); echo "adj_al_morir=${ADJ:-no_sample}"; } || echo "sin log nuevo"
echo "--- 2. demostracion de la regla del kernel: no se puede bajar el adj heredado ---"
( echo 200 > /proc/self/oom_score_adj 2>/dev/null; echo 0 > /proc/self/oom_score_adj 2>/dev/null && echo "BAJO_a_0 (kernel permisivo)" || echo "KERNEL_DENEGO_bajar_de_200_a_0 — confirmado" ) &
wait
echo "--- 3. broker blindado: demonio hijo del bridge (adj=0) que lanza apps ---"
cat > /usr/local/bin/artcraft-broker <<'EOF'
#!/bin/bash
# Broker: nace del bridge (adj=0). Toda app que lance hereda adj=0 — LMKD no la puede matar.
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/home/dexuser
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
mkdir -p /tmp/broker
[ -p /tmp/broker/launch.fifo ] || mkfifo /tmp/broker/launch.fifo
while read APP < /tmp/broker/launch.fifo; do
  [ -z "$APP" ] || [ ! -x "$APP" ] && continue
  /usr/local/bin/artcraft-app-launch "$APP" >/dev/null 2>&1 &
done
EOF
chmod 755 /usr/local/bin/artcraft-broker
cat > /usr/local/bin/artcraft-broker-client <<'EOF'
#!/bin/bash
# Cliente del dock: delega el lanzamiento al broker blindado (adj=0). Si no hay broker, fallback directo.
if [ -p /tmp/broker/launch.fifo ]; then
  timeout 2 bash -c 'printf "%s\n" "$1" > /tmp/broker/launch.fifo' _ "$1" 2>/dev/null && exit 0
fi
exec /usr/local/bin/artcraft-app-launch "$@"
EOF
chmod 755 /usr/local/bin/artcraft-broker-client
pkill -f artcraft-broker 2>/dev/null
nohup /usr/local/bin/artcraft-broker >/tmp/broker.log 2>&1 &
sleep 1
BP=$(pgrep -f "artcraft-broker$" | head -1)
echo "broker_pid=${BP:-NO_NACIO} adj=$(cat /proc/$BP/oom_score_adj 2>/dev/null)"
echo "--- 4. repuntar los 4 iconos al cliente del broker ---"
for PKG in vectorcraft photocraft filmcraft lightcraft; do
  D=$(dpkg -L $PKG 2>/dev/null | grep -E "\.desktop$" | head -1)
  BIN=$(grep "^Exec=" "$D" 2>/dev/null | head -1 | sed 's/^Exec=//' | awk '{print $NF}')
  [ -n "$D" ] && [ -n "$BIN" ] && sed -i "s|^Exec=.*|Exec=/usr/local/bin/artcraft-broker-client $BIN|" "$D" && echo "$PKG -> broker-client ($BIN)"
done
update-desktop-database /usr/share/applications 2>/dev/null || true
echo "--- 5. PRUEBA EN VIVO: lanzar vectorcraft via broker y monitorear 20 s ---"
/usr/local/bin/artcraft-broker-client /usr/bin/vectorcraft
AP=$(pgrep -x vectorcraft | head -1)
echo "app_pid=$AP adj=$(cat /proc/$AP/oom_score_adj 2>/dev/null) (esperado 0)"
DEAD=""
for i in $(seq 1 10); do
  sleep 2
  kill -0 ${AP:-99999} 2>/dev/null || { echo "MURIO_EN_$((i*2))s"; DEAD=si; break; }
done
[ -z "$DEAD" ] && echo "SOBREVIVIO_20s_VIA_BROKER" && pkill -x vectorcraft 2>/dev/null
echo "--- 6. salud ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
pgrep -f "artcraft-broker$" >/dev/null && echo BROKER_PERSISTE || echo BROKER_MURIO
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a60.sh 2>&1
rm -f "$T/a60.sh"
echo "VEREDICTO: si la prueba 5 muestra adj=0 y SOBREVIVIO, el usuario reintenta desde el dock — la app nace del broker, hereda adj=0 y LMKD no la mata. La mitad de Android sigue siendo recomendable: Termux y Termux:X11 en 'Sin restricciones' de bateria para blindar tambien al propio sistema, no solo a las apps."
echo "=== MISION-A60-BROKER-BLINDADO COMPLETE ==="
echo "### BRIDGE MARKER ###"