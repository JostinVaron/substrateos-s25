echo "=== MISION-A30-GPU — ¿los programas usan la Adreno 830 o caen a software? $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
G() { proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -c "$1" 2>&1; }

echo "--- 1. BASELINE SIN WRAPPER (como lanzaria una app ingenua) ---"
G 'export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex HOME=/home/dexuser
DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr 2>/dev/null)
glxinfo -B 2>/dev/null | grep -E "renderer|OpenGL version|Accelerated" | head -4'

echo "--- 2. CON SUBSTRATE-GPU-RUN (receta del repo para apps GPU) ---"
G 'export DISPLAY=:0
substrate-gpu-run glxinfo -B 2>/dev/null | grep -E "renderer|OpenGL version|Accelerated" | head -4'

echo "--- 3. VULKAN VIA WRAPPER (turnip directo) ---"
G 'export DISPLAY=:0
substrate-gpu-run vulkaninfo --summary 2>/dev/null | grep -E "deviceName|driverName|apiVersion" | head -8'

echo "--- 4. PRUEBA DURISIMA: fds kgsl abiertos por el proceso GL ---"
G 'export DISPLAY=:0
substrate-gpu-run glxgears >/tmp/rt-dex/gpu-gears.log 2>&1 &
P=$!
sleep 7
if [ -d /proc/$P ]; then
  K=$(ls -l /proc/$P/fd 2>/dev/null | grep -c kgsl)
  echo "kgsl_fds_del_proceso_GL=$K"
  echo "renderer_del_proceso: $(grep -m1 renderer /tmp/rt-dex/gpu-gears.log 2>/dev/null)"
  kill $P 2>/dev/null
else
  echo "proceso murio antes de 7 s; log:"
  tail -5 /tmp/rt-dex/gpu-gears.log
fi'

echo "--- 5. FPS comparado (12 s cada uno) ---"
echo "FPS software (llvmpipe):"
G 'export DISPLAY=:0
timeout 12 glxgears 2>&1 | grep -oE "[0-9]+\.?[0-9]* FPS" | tail -1'
echo "FPS hardware (Adreno via wrapper):"
G 'export DISPLAY=:0
timeout 12 substrate-gpu-run glxgears 2>&1 | grep -oE "[0-9]+\.?[0-9]* FPS" | tail -1'

echo "--- 6. el shell sobrevivio (regla de oro) ---"
G 'pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO'

echo "--- 7. sintesis automatica ---"
echo "LECTURA: seccion 1 debe decir llvmpipe/swrast (compositor software, por diseno)."
echo "Secciones 2-4 deben decir Adreno 830 con kgsl_fds>=1: esa es la prueba de GPU REAL."
echo "Si seccion 4 reporta kgsl_fds=0 y renderer zink/llvmpipe, la GPU NO esta en uso y hay que arreglar."
echo "=== MISION-A30-GPU COMPLETE ==="
echo "### BRIDGE MARKER ###"