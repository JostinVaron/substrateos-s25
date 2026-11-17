echo "=== MISION-A76-CONSUMO-WTM — consumo real de la cadena WTM en el S25 (solo lectura) $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
adb connect 127.0.0.1:5555 >/dev/null 2>&1 || true
ADB="adb -s 127.0.0.1:5555"
echo "--- 1. esta viva la cadena WTM? ---"
SP=$("$ADB" shell 'ps -A 2>/dev/null | grep app_process | head -3' 2>/dev/null | tr -d '\r')
echo "scrcpy_app_process: ${SP:-NO_HAY}"
RP=$(pgrep -f "server.py" | head -1)
echo "relay_python_pid=${RP:-NO_CORRE}"
if [ -n "$RP" ]; then
  echo "relay_RSS=$(grep VmRSS /proc/$RP/status 2>/dev/null | awk '{print $2}')kB"
  echo "relay_cpu_utos=$(awk '{print $14+$15}' /proc/$RP/stat 2>/dev/null) ticks, uptime=$(awk '{print int($1)}' /proc/uptime)s"
fi
curl -sk --max-time 3 https://127.0.0.1:8443/healthz 2>/dev/null | head -c 200 && echo "" || echo "healthz_sin_respuesta (relay caido o WTM apagado)"
echo "--- 2. scrcpy server: RSS y CPU (desde Android) ---"
SPID=$("$ADB" shell 'ps -A 2>/dev/null | grep app_process | awk "{print \$2}" | head -1' 2>/dev/null | tr -d '\r')
if [ -n "$SPID" ]; then
  echo "scrcpy_pid=$SPID rss=$("$ADB" shell "grep VmRSS /proc/$SPID/status 2>/dev/null" 2>/dev/null | tr -d '\r')"
  "$ADB" shell "top -n 1 -b -p $SPID 2>/dev/null | tail -2" 2>/dev/null | tr -d '\r' || echo "top_no_disponible"
  echo "scrcpy_cpu_restante_linea: ver arriba %CPU"
else
  echo "scrcpy_no_activo — WTM probablemente apagado; se mide solo el costo en reposo"
fi
echo "--- 3. top general de CPU en Android (quien quema ahora) ---"
"$ADB" shell "top -n 1 -b -o %CPU 2>/dev/null | head -15" 2>/dev/null | tr -d '\r' || echo "top_fallo"
echo "--- 4. bateria: corriente y nivel AHORA ---"
"$ADB" shell dumpsys battery 2>/dev/null | grep -iE "level|status|current now|Charge counter|voltage" | tr -d '\r' | head -6
echo "--- 5. cpuinfo acumulado: top consumidores desde boot ---"
"$ADB" shell dumpsys cpuinfo 2>/dev/null | head -20 | tr -d '\r'
echo "--- 6. PSI y memoria ---"
echo "psi_cpu: $(grep -E '^(some|full)' /proc/pressure/cpu 2>/dev/null | tr '\n' ' ')"
echo "psi_mem: $(grep -E '^(some|full)' /proc/pressure/memory 2>/dev/null | tr '\n' ' ')"
grep -E "MemAvailable|SwapFree|SwapTotal" /proc/meminfo 2>/dev/null
echo "--- 7. hotspot (radio = sospechoso #1 de bateria) ---"
"$ADB" shell "cmd wifi status 2>/dev/null | head -2" 2>/dev/null | tr -d '\r' || echo "cmd_wifi_no_disponible"
"$ADB" shell "dumpsys wifi 2>/dev/null | grep -iE 'mWifiApState|apState|hotspot' | head -3" 2>/dev/null | tr -d '\r' || true
echo "termux_wake_lock: $(pgrep -f termux-wake-lock >/dev/null && echo activo || echo revisar)"
echo "--- 8. termux propio: procesos y RAM total ---"
ps -o pid,rss,args 2>/dev/null | head -12
echo "VEREDICTO: comparar %CPU de app_process (scrcpy), python3 (relay) y com.termux en cpuinfo; corriente uA con/sin WTM activo define el costo real de bateria. Si scrcpy NO esta activo, repetir la medicion con DeX encendido para comparar delta."
echo "=== MISION-A76-CONSUMO-WTM COMPLETE ==="
echo "### BRIDGE MARKER ###"