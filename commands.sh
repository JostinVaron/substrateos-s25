echo "=== MISION-A57-FIRMA-VECTORCRAFT — leer la firma del crash capturado $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/a57.sh" <<'EOS'
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/root
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
echo "--- 1. todos los logs de sesiones de app (mas recientes primero) ---"
ls -lt /tmp/app-session-*.log 2>/dev/null | head -6
L=$(ls -t /tmp/app-session-*.log 2>/dev/null | head -1)
if [ -z "$L" ]; then
  echo "SIN_LOG — la trampa no disparo (posible: se abrio sin pasar por el wrapper)"
  echo "== verificacion: como se lanzo la ultima vez? =="
  ps aux 2>/dev/null | grep -iE "vector|photocraft|filmcraft|lightcraft" | grep -v grep | head -3
  echo "== log propio de vectorcraft (su stderr interno) =="
  tail -20 /home/dexuser/.config/vectorcraft/logs/vectorcraft.log 2>/dev/null || echo "sin log interno"
else
  echo "--- 2. FIRMA COMPLETA del ultimo crash: $L ---"
  cat "$L"
  echo "--- 3. interpretacion de la firma ---"
  RC=$(grep -oE "EXIT_CODE=[0-9]+" "$L" | tail -1 | cut -d= -f2)
  echo "exit_code=${RC:-no_capturado}"
  case "${RC:-0}" in
    101) echo "FIRMA: PANIC RUST/WINIT — mismo bug del launcher. Cura: workarounds de entorno." ;;
    137) echo "FIRMA: SIGKILL — matado por memoria (OOM) o por gestion de Android. Ver memavail en los ultimos samples." ;;
    139) echo "FIRMA: SIGSEGV — segmentation fault, posible problema de driver Vulkan/Adreno en proot." ;;
    1) echo "FIRMA: exit 1 — fallo de inicializacion (ver stderr arriba)." ;;
    0) echo "FIRMA: exit 0 — la app cerro 'limpia' sola (posible exito, no crash)." ;;
    *) echo "FIRMA: codigo $RC — ver stderr arriba." ;;
  esac
  echo "--- 4. RAM justo antes de morir (ultimos 3 samples) ---"
  grep "rss_kb" "$L" | tail -3
fi
echo "--- 5. si el launcher o algo la relanzo, salud general ---"
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
free -m | head -2
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/a57.sh 2>&1
rm -f "$T/a57.sh"
echo "VEREDICTO: la firma capturada decide la cura. PANIC winit (101) = mismos workarounds que el launcher. SIGKILL (137) con memavail caido = disciplina de memoria. SIGSEGV (139) = frente nuevo: driver Vulkan/Adreno bajo proot."
echo "=== MISION-A57-FIRMA-VECTORCRAFT COMPLETE ==="
echo "### BRIDGE MARKER ###"