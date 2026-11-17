echo "=== MISION-A74-BROKER-V2-RUNNER-PERSISTENTE — cura definitiva: apps con padre eterno $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
RT="$PREFIX/tmp/rt-dex"
BK="$HOME/.local/share/substrate/rt-dex"
WORK="$HOME/substrate/bridge"
mkdir -p "$RT" "$BK"
echo "--- 1. detener broker viejo (arquitectura efimera) ---"
pkill -f app-broker-termux 2>/dev/null && echo "broker_viejo_detenido" || echo "broker_viejo ausente"
pkill -f "app-runner-inner" 2>/dev/null
sleep 1
echo "--- 2. escribir runner INTERIOR (corre dentro de proot, es el padre eterno) ---"
cat > "$RT/app-runner-inner.sh" <<'INNER'
#!/bin/bash
# app-runner-inner.sh - PADRE ETERNO de las apps craft. Corre DENTRO de un proot
# que NUNCA sale. Lee el fifo del dock y lanza cada app como hija suya (setsid).
# Regla descubierta (A72/A73): en OneUI un phantom sobrevive mientras su arbol
# padre vive; muere apenas el proot padre sale. Por eso el broker v1 (login
# efimero por app) mataba a las apps al salir su proot lanzador.
set -u
RT=/tmp/rt-dex
FIFO=/tmp/launch.fifo
[ -p "$FIFO" ] || mkfifo "$FIFO"
echo $$ > "$RT/app-runner.pid"
while true; do
  if read -r APP < "$FIFO"; do
    [ -z "$APP" ] && continue
    STAMP=$(date +%H:%M:%S)
    echo "[$STAMP] lanzando $APP" >> /tmp/app-live.log
    # resolver binario con variantes de nombre
    CMD=""
    for CAND in "$APP" "${APP//craft/-craft}" "${APP//-/_}"; do
      P=$(command -v "$CAND" 2>/dev/null) && { CMD="$P"; break; }
    done
    if [ -z "$CMD" ]; then
      echo "[$STAMP] ERROR: no encontre binario para $APP" >> /tmp/app-live.log
      continue
    fi
    (
      export DISPLAY=:0 HOME=/home/dexuser XDG_RUNTIME_DIR=/tmp/rt-dex
      export XDG_CURRENT_DESKTOP=ubuntu:GNOME XDG_SESSION_TYPE=x11
      export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
      setsid /usr/local/bin/substrate-gpu-run "$CMD" >> "/tmp/app-live-$APP.log" 2>&1 &
      APID=$!
      taskset -apc 6-7 "$APID" >/dev/null 2>&1
      echo "[$STAMP] lanzada $APP pid=$APID" >> /tmp/app-live.log
    )
  else
    sleep 1
  fi
done
INNER
chmod 755 "$RT/app-runner-inner.sh"
cp -f "$RT/app-runner-inner.sh" "$BK/app-runner-inner.sh"
echo "runner_interior_desplegado_en_RT_y_BK"
echo "--- 3. broker v2 nativo: unico trabajo = mantener vivo al runner (padre eterno) ---"
cat > "$WORK/app-broker-termux.sh" <<'BROKER'
#!/data/data/com.termux/files/usr/bin/bash
# app-broker-termux v2 - mantiene vivo al runner persistente (padre eterno de las
# apps). Ya NO lanza apps el mismo: eso lo hace /tmp/rt-dex/app-runner-inner.sh
# dentro de un proot que nunca sale (cura del bug de muertes signal 9).
set -u
RT="$PREFIX/tmp/rt-dex"
BK="$HOME/.local/share/substrate/rt-dex"
[ -f "$BK/app-runner-inner.sh" ] && cp -f "$BK/app-runner-inner.sh" "$RT/app-runner-inner.sh"
while true; do
  PID=$(cat "$RT/app-runner.pid" 2>/dev/null)
  if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
    setsid nohup proot-distro login ubuntu-gnome --shared-tmp -- \
      bash "$RT/app-runner-inner.sh" >> "$PREFIX/tmp/app-runner-sup.log" 2>&1 < /dev/null &
    echo "$(date -u +%FT%TZ) runner relanzado" >> "$PREFIX/tmp/app-runner-sup.log"
  fi
  sleep 20
done
BROKER
chmod 755 "$WORK/app-broker-termux.sh"
cp -f "$WORK/app-broker-termux.sh" "$BK/app-broker-termux.sh"
echo "broker_v2_desplegado"
setsid nohup bash "$WORK/app-broker-termux.sh" >> "$WORK/broker.log" 2>&1 &
sleep 3
RPID=$(cat "$RT/app-runner.pid" 2>/dev/null)
echo "runner_pid=${RPID:-NO} $( [ -n "$RPID" ] && kill -0 "$RPID" 2>/dev/null && echo VIVO || echo MUERTO )"
echo "--- 4. versionar al repo (gh api, crea o actualiza) ---"
for F in app-runner-inner.sh app-broker-termux.sh; do
  if [ "$F" = "app-broker-termux.sh" ]; then P="scripts/termux/$F"; SRC="$WORK/$F"; else P="scripts/proot-rt/$F"; SRC="$BK/$F"; fi
  SHA=$(gh api "repos/JostinVaron/substrateos-s25/contents/$P?ref=bridge" -q .sha 2>/dev/null)
  B64=$(base64 -w0 "$SRC")
  if [ -n "$SHA" ] && [ "$SHA" != "null" ]; then
    printf '{"message":"A74: %s v2","branch":"bridge","content":"%s","sha":"%s"}' "$F" "$B64" "$SHA" > "$PREFIX/tmp/c.json"
  else
    printf '{"message":"A74: %s v2","branch":"bridge","content":"%s"}' "$F" "$B64" > "$PREFIX/tmp/c.json"
  fi
  gh api -X PUT "repos/JostinVaron/substrateos-s25/contents/$P" --input "$PREFIX/tmp/c.json" >/dev/null 2>&1 && echo "repo: $P OK" || echo "repo: $P fallo (no critico)"
  rm -f "$PREFIX/tmp/c.json"
done
echo "--- 5. PRUEBA DE FUEGO: filmcraft via fifo del dock, 3 min, padre eterno ---"
echo filmcraft > "$PREFIX/tmp/launch.fifo"
sleep 10
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
FP=$(pgrep -x filmcraft | head -1)
echo "filmcraft_pid=${FP:-NO_NACIO}"
if [ -n "$FP" ]; then
  echo "adj_al_nacer=$(cat /proc/$FP/oom_score_adj 2>/dev/null)"
  PPID_APP=$(awk "/^PPid:/{print \$2}" /proc/$FP/status 2>/dev/null)
  echo "ppid=$PPID_APP (debe ser el runner $(cat /tmp/rt-dex/app-runner.pid), NO un login efimero)"
  T0=$(date +%s); OK=1
  for i in $(seq 1 36); do
    sleep 5
    EL=$(( $(date +%s) - T0 ))
    kill -0 "$FP" 2>/dev/null || { echo "MURIO_EN_t+${EL}s"; OK=0; break; }
    [ $((i % 6)) -eq 0 ] && echo "t+${EL}s VIVA adj=$(cat /proc/$FP/oom_score_adj 2>/dev/null)"
  done
  [ $OK -eq 1 ] && echo "RESULTADO: FILMCRAFT_SOBREVIVIO_3MIN_CON_PADRE_ETerno" || echo "RESULTADO: MURIO"
else
  tail -3 /tmp/app-live.log
fi' 2>&1
echo "--- 6. estado final ---"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'pgrep -x filmcraft >/dev/null && echo FILMCRAFT_VIVA || echo FILMCRAFT_MUERTA; pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO' 2>/dev/null
RPID=$(cat "$RT/app-runner.pid" 2>/dev/null); kill -0 ${RPID:-99999} 2>/dev/null && echo "RUNNER_ETERNO_VIVO pid=$RPID" || echo RUNNER_MUERTO
pgrep -f app-broker-termux >/dev/null && echo BROKER_V2_VIVO || echo BROKER_V2_MUERTO
tail -5 "$PREFIX/tmp/app-live.log" 2>/dev/null
echo "VEREDICTO: si filmcraft sobrevivio con ppid=runner y adj=0 estable, el dock queda curado: cada app nace con padre eterno. El usuario prueba abriendo apps DESDE EL DOCK como siempre y usandolas largo rato."
echo "=== MISION-A74-BROKER-V2-RUNNER-PERSISTENTE COMPLETE ==="
echo "### BRIDGE MARKER ###"