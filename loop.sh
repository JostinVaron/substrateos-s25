#!/data/data/com.termux/files/usr/bin/bash
# SubstrateOS bridge agent v4 - status solo en cambio de estado o latido de 10 min.
# MIGRADO 2026-11-16: este repo (substrateos-s25) es ahora la casa del bridge.
set -u
BRANCH=bridge
REPO=JostinVaron/substrateos-s25
MARKER="### BRIDGE MARKER ###"
WORK="$HOME/substrate/bridge"
LOCKF="$WORK/v4.lock"
if [ -f "$LOCKF" ] && kill -0 "$(cat "$LOCKF" 2>/dev/null)" 2>/dev/null; then echo "[v4] ya activo"; exit 1; fi
mkdir -p "$WORK"; echo $$ > "$LOCKF"
STATE="idle"; MISSION="esperando comandos"; LAST=""; LASTPUSH=0
say(){ echo "[bridge-v4 $(date +%H:%M:%S)] $*"; }
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
  { echo "loop: v4 (pid $$)"; echo "ts: $(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "estado: $STATE"; echo "mision: $MISSION"; } > "$WORK/status.txt"
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
say "v4 iniciado (migrado a substrateos-s25) - silencioso"
push_status
while true; do
  if fetch && grep -F "$MARKER" "$WORK/commands.sh" >/dev/null 2>&1; then
    HASH=$(md5sum "$WORK/commands.sh" | cut -d' ' -f1)
    if [ "$HASH" != "$LAST" ]; then
      grep -v -F "$MARKER" "$WORK/commands.sh" > "$WORK/run.sh"
      MISSION=$(head -8 "$WORK/run.sh" | grep -oE 'MISION-[A-Z0-9]+|LOOP-UPGRADE' | head -1); [ -z "$MISSION" ] && MISSION="(sin nombre)"
      say "ejecutando $MISSION"
      STATE="corriendo"; push_status
      { echo "=== BRIDGE RUN $(date -u +%Y-%m-%dT%H:%M:%SZ) (v4) ==="; bash "$WORK/run.sh" 2>&1; echo "=== EXIT=$? ==="; } > "$WORK/output.txt"
      STATE="subiendo output"; push_status
      push_output
      STATE="idle"; MISSION="esperando comandos"; LAST="$HASH"; push_status
      say "mision completada"
    fi
  else
    NOW=$(date +%s)
    if [ $((NOW - LASTPUSH)) -ge 600 ]; then push_status; fi
  fi
  sleep 15
done