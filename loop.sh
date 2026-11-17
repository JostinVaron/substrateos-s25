#!/data/data/com.termux/files/usr/bin/bash
# SubstrateOS bridge agent v6 - v5 + guardián anti-LMKD (re-aplica blindaje phantom tras reinicios).
set -u
BRANCH=bridge
REPO=JostinVaron/substrateos-s25
MARKER="### BRIDGE MARKER ###"
WORK="$HOME/substrate/bridge"
LOCKF="$WORK/v6.lock"
if [ -f "$LOCKF" ] && kill -0 "$(cat "$LOCKF" 2>/dev/null)" 2>/dev/null; then echo "[v6] ya activo"; exit 1; fi
mkdir -p "$WORK"; echo $$ > "$LOCKF"
STATE="idle"; MISSION="esperando comandos"; LAST=""; LASTPUSH=0
say(){ echo "[bridge-v6 $(date +%H:%M:%S)] $*"; }
ensure_broker(){
  if ! pgrep -f app-broker-termux >/dev/null 2>&1; then
    if [ -f "$WORK/app-broker-termux.sh" ]; then
      setsid nohup bash "$WORK/app-broker-termux.sh" >> "$WORK/broker.log" 2>&1 &
      say "broker nativo relanzado (pid $!)"
    fi
  fi
}
ensure_phantom_guard(){
  # Android borra device_config al reiniciar: re-aplicar el blindaje anti-LMKD.
  command -v adb >/dev/null 2>&1 || return 0
  adb connect 127.0.0.1:5555 >/dev/null 2>&1 || return 0
  ADB="adb -s 127.0.0.1:5555"
  MP=$($ADB shell settings get global settings_enable_monitor_phantom_procs 2>/dev/null | tr -d '\r')
  if [ "$MP" != "false" ] && [ "$MP" != "0" ]; then
    $ADB shell settings put global settings_enable_monitor_phantom_procs false >/dev/null 2>&1 \
      && say "phantom guard: monitor re-aplicado false"
  fi
  XP=$($ADB shell device_config get activity_manager max_phantom_processes 2>/dev/null | tr -d '\r')
  if [ "$XP" != "2147483647" ]; then
    $ADB shell device_config set_sync_disabled_for_tests persistent >/dev/null 2>&1
    $ADB shell device_config put activity_manager max_phantom_processes 2147483647 >/dev/null 2>&1 \
      && say "phantom guard: max_phantom re-aplicado"
  fi
}
put_file(){
  local B64 SHA
  B64=$(base64 -w0 "$2")
  SHA=$(gh api "repos/$REPO/contents/$1?ref=$BRANCH" -q .sha 2>/dev/null)
  if [ -n "$SHA" ] && [ "$SHA" != "null" ]; then
    gh api -X PUT "repos/$REPO/contents/$1" -f message="$3" -f branch="$BRANCH" -f content="$B64" -f sha="$SHA" >/dev/null 2>&1
  else
    gh api -X PUT "repos/$REPO/contents/$1" -f message="$3" -f branch="$BRANCH" -f content="$B64" >/dev/null 2>&1
  fi
}
push_status(){
  BROK="muerto"
  pgrep -f app-broker-termux >/dev/null 2>&1 && BROK="vivo"
  { echo "loop: v6 (pid $$)"; echo "ts: $(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "estado: $STATE"; echo "mision: $MISSION"; echo "broker_apps: $BROK"; } > "$WORK/status.txt"
  put_file status.txt "$WORK/status.txt" "estado: $STATE $MISSION"
  LASTPUSH=$(date +%s)
}
push_output(){
  base64 -w0 "$WORK/output.txt" > "$WORK/out.b64"
  SHA=$(gh api "repos/$REPO/contents/output.txt?ref=$BRANCH" -q .sha 2>/dev/null)
  printf '{"message":"bridge: output final","branch":"%s","content":"' "$BRANCH" > "$WORK/out.json"
  cat "$WORK/out.b64" >> "$WORK/out.json"
  if [ -n "$SHA" ] && [ "$SHA" != "null" ]; then printf '","sha":"%s"}' "$SHA" >> "$WORK/out.json"; else printf '"}' >> "$WORK/out.json"; fi
  gh api -X PUT "repos/$REPO/contents/output.txt" --input "$WORK/out.json" >/dev/null 2>&1
}
fetch(){ gh api "repos/$REPO/contents/commands.sh?ref=$BRANCH" -q .content 2>/dev/null | base64 -d > "$WORK/commands.sh" 2>/dev/null; }
say "v6 iniciado (con broker nativo + guardián anti-LMKD) - silencioso"
ensure_broker
ensure_phantom_guard
push_status
while true; do
  if fetch && grep -F "$MARKER" "$WORK/commands.sh" >/dev/null 2>&1; then
    HASH=$(md5sum "$WORK/commands.sh" | cut -d' ' -f1)
    if [ "$HASH" != "$LAST" ]; then
      grep -v -F "$MARKER" "$WORK/commands.sh" > "$WORK/run.sh"
      MISSION=$(head -8 "$WORK/run.sh" | grep -oE 'MISION-[A-Z0-9]+|LOOP-UPGRADE' | head -1); [ -z "$MISSION" ] && MISSION="(sin nombre)"
      say "ejecutando $MISSION"
      STATE="corriendo"; push_status
      { echo "=== BRIDGE RUN $(date -u +%Y-%m-%dT%H:%M:%SZ) (v6) ==="; bash "$WORK/run.sh" 2>&1; echo "=== EXIT=$? ==="; } > "$WORK/output.txt"
      STATE="subiendo output"; push_status
      push_output
      STATE="idle"; MISSION="esperando comandos"; LAST="$HASH"; push_status
      say "mision completada"
    fi
  else
    NOW=$(date +%s)
    if [ $((NOW - LASTPUSH)) -ge 600 ]; then ensure_broker; ensure_phantom_guard; push_status; fi
  fi
  sleep 15
done