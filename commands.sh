echo "=== MISION-DEMO-STREAM — demostracion en tiempo real $(date -u +%FT%TZ) ==="
echo "observa: una linea nueva cada 2 segundos"
for i in 1 2 3 4 5 6 7 8 9 10; do
  echo "linea $i/10 — $(date +%H:%M:%S)"
  sleep 2
done
echo "VEREDICTO: STREAM_OK — acabas de ver al bridge trabajando en vivo"
echo "=== MISION-DEMO-STREAM COMPLETE ==="
echo "### BRIDGE MARKER ###"