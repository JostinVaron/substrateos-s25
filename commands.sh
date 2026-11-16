echo "=== MISION-A42-ARTCRAFT-LAUNCHER — terreno + launcher para la suite ArtCraft $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
T="$PREFIX/tmp"
cat > "$T/ac.sh" <<'EOS'
set -u
echo "--- 1. dependencias comunes de apps 3D (directiva 03-APPS-GPU.md) ---"
apt-get install -y libgl1 libegl1 libglx-mesa0 libx11-6 libxext6 libxrender1 libxkbcommon0 libfontconfig1 libfreetype6 libglib2.0-0 libgtk-3-0 libgtk-4-1 >/tmp/ac-deps.log 2>&1
echo "deps_exit=$?"; tail -2 /tmp/ac-deps.log
echo "--- 2. carpeta de apps del usuario (directiva repo) ---"
mkdir -p /home/dexuser/Apps
chown dexuser:dexuser /home/dexuser/Apps 2>/dev/null || true
echo "--- 3. instalando artcraft-launcher (/usr/local/bin) ---"
cat > /usr/local/bin/artcraft-launcher <<'EOX'
#!/bin/bash
# ArtCraft launcher — GPU/proot-safe. Directivas: docs/03-APPS-GPU.md
# - App OpenGL/3D: SIEMPRE via substrate-gpu-run (nunca directo: heredaria llvmpipe)
# - AppImage en proot: --appimage-extract-and-run (sin FUSE)
# - Datos en /home/dexuser; nunca pkill -f
APPS=/home/dexuser/Apps
cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  status)
    echo "[GPU]"; substrate-gpu-run glxinfo -B 2>/dev/null | grep -E "renderer|OpenGL core profile version" | head -2
    echo "[Apps en $APPS]"; ls -la "$APPS" 2>/dev/null | tail -n +2
    ;;
  install)
    SRC="${1:-}"
    if [ -z "$SRC" ]; then echo "uso: artcraft-launcher install <archivo-local|URL>"; exit 1; fi
    case "$SRC" in
      http://*|https://*)
        OUT="$APPS/$(basename "${SRC%%\?*}")"
        echo "descargando $SRC -> $OUT"
        curl -L --max-time 900 -o "$OUT" "$SRC" || { echo "DESCARGA_FALLO"; exit 1; }
        SRC="$OUT" ;;
    esac
    case "$SRC" in
      *.deb)
        echo "instalando .deb via apt..."; apt-get install -y "$SRC" ;;
      *.AppImage|*.appimage)
        chmod +x "$SRC"; echo "AppImage listo en $SRC (se ejecutara con --appimage-extract-and-run)" ;;
      *)
        echo "formato no reconocido: $SRC — solo .deb o .AppImage (directiva repo: evitar flatpak/snap)" ;;
    esac ;;
  run)
    if command -v artcraft >/dev/null 2>&1; then exec substrate-gpu-run artcraft "$@"; fi
    APP=$(ls "$APPS"/*.AppImage "$APPS"/*.appimage 2>/dev/null | head -1)
    if [ -n "$APP" ]; then exec substrate-gpu-run "$APP" --appimage-extract-and-run "$@"; fi
    MSG="ArtCraft aun no esta instalado.\n\nColoca el instalador (.deb o .AppImage) en:\n  $APPS\ny ejecuta:\n  artcraft-launcher install <archivo>\n\nO pasale una URL directa:\n  artcraft-launcher install <URL>"
    if [ -n "${DISPLAY:-}" ] && command -v zenity >/dev/null 2>&1; then
      zenity --info --title="ArtCraft Launcher" --text="$MSG" 2>/dev/null
    else
      echo "$MSG"
    fi ;;
  *)
    echo "uso: artcraft-launcher {status|install <ruta|URL>|run [args]}" ;;
esac
EOX
chmod 755 /usr/local/bin/artcraft-launcher
echo "launcher_instalado"
echo "--- 4. icono en el dock (sesion root: /usr/share/applications) ---"
printf '[Desktop Entry]\nType=Application\nName=ArtCraft Suite (GPU)\nExec=artcraft-launcher run\nIcon=applications-graphics\nTerminal=false\nCategories=Graphics;3DGraphics;\n' > /usr/share/applications/artcraft-gpu.desktop
chmod 644 /usr/share/applications/artcraft-gpu.desktop
update-desktop-database /usr/share/applications 2>/dev/null || true
echo "desktop_ok"
echo "--- 5. verificacion (checklist del repo) ---"
command -v substrate-gpu-run >/dev/null && echo GPU_WRAPPER_OK || echo GPU_WRAPPER_FALTA
artcraft-launcher status 2>&1 | head -5
dpkg --audit >/dev/null 2>&1; echo "audit_exit=$?"
echo "--- 6. ayuda del launcher ---"
artcraft-launcher 2>&1 | head -1
echo "FIN_INNER"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/ac.sh 2>&1
rm -f "$T/ac.sh"
echo "VEREDICTO: launcher listo. La suite misma NO se descargo — el repo manda no inventar rutas de ArtCraft. Cuando exista URL o archivo oficial: artcraft-launcher install <URL|ruta> la instala con GPU Adreno en un paso."
echo "=== MISION-A42-ARTCRAFT-LAUNCHER COMPLETE ==="
echo "### BRIDGE MARKER ###"