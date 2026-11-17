echo "=== MISION-A69-PHANTOM-KILLER — identificar y desactivar al asesino de procesos hijos $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
echo "--- 1. adb disponible? ---"
command -v adb >/dev/null && echo "adb_ok" || { echo "adb_falta — abortar"; exit 1; }
adb connect 127.0.0.1:5555 2>/dev/null | head -1
ADB="adb -s 127.0.0.1:5555"
echo "--- 2. FORENSE: ha actuado el phantom killer? ---"
echo "== estado actual del vigilante =="
echo "monitor_phantom_procs = $($ADB shell settings get global settings_enable_monitor_phantom_procs 2>/dev/null | tr -d '\r')"
echo "max_phantom_processes  = $($ADB shell device_config get activity_manager max_phantom_processes 2>/dev/null | tr -d '\r')"
echo "== logcat: muertes phantom y lmkd recientes =="
$ADB shell logcat -d 2>/dev/null | grep -iE "phantom|lmkd.*kill|lowmemorykiller" | tail -15 || echo "logcat vacio"
echo "== dumpsys: procstate y adj de termux AHORA =="
$ADB shell dumpsys activity processes 2>/dev/null | grep -iE "termux" | head -12 || echo "dumpsys sin coincidencias"
echo "--- 3. DESACTIVAR el phantom process killer (persistente) ---"
$ADB shell settings put global settings_enable_monitor_phantom_procs false && echo "monitor_phantom_procs=false OK"
$ADB shell device_config set_sync_disabled_for_tests persistent && echo "device_config sync off OK"
$ADB shell device_config put activity_manager max_phantom_processes 2147483647 && echo "max_phantom_processes=2147483647 OK"
echo "--- 4. VERIFICACION de los cambios ---"
echo "monitor_phantom_procs = $($ADB shell settings get global settings_enable_monitor_phantom_procs 2>/dev/null | tr -d '\r')"
echo "max_phantom_processes  = $($ADB shell device_config get activity_manager max_phantom_processes 2>/dev/null | tr -d '\r')"
echo "--- 5. salud del escritorio (no se toco nada del escritorio) ---"
pgrep -f app-broker-termux >/dev/null && echo BROKER_VIVO || echo BROKER_MUERTO
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO' 2>/dev/null
echo "VEREDICTO: si el forense (paso 2) muestra muertes phantom en logcat, asesino confirmado y ya desactivado. El usuario debe probar: abrir EffectCraft desde el dock, USARLA varios minutos desde Termux:X11 (escenario exacto donde moria), y ver si sobrevive. Nota: tras un REINICIO del telefono el flag de settings persiste, pero device_config puede requerir re-aplicar — si los kills vuelven tras reinicio, despachar solo el paso 3 de nuevo."
echo "=== MISION-A69-PHANTOM-KILLER COMPLETE ==="
echo "### BRIDGE MARKER ###"