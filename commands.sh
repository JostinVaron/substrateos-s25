echo "=== MISION-A31 — integridad post-tests + preparacion para instalar apps $(date -u +%FT%TZ) ==="
termux-wake-lock 2>/dev/null
G() { proot-distro login ubuntu-gnome --shared-tmp -- bash -c "$1" 2>&1; }

echo "--- 1. INTEGRIDAD: session GNOME ---"
G 'export DISPLAY=:0
pgrep -x gnome-shell >/dev/null && echo SHELL_VIVO || echo SHELL_MUERTO
wmctrl -l 2>/dev/null; echo "ventanas_abiertas=$?"
xdpyinfo 2>/dev/null | grep dimensions'
echo "--- 2. INTEGRIDAD: procesos huerfanos de los tests ---"
G 'pgrep -f glxgears >/dev/null && echo "GLXGEARS_AUN_VIVE (mal)" || echo GLXGEARS_CERRADO_OK
pgrep -f gnome-calculator >/dev/null && echo "CALC_AUN_VIVA" || echo CALC_CERRADA_OK
echo "logins proot activos: $(pgrep -c -f "proot-distro login" 2>/dev/null || echo 0)"'

echo "--- 3. INTEGRIDAD: salud del shell (sin crash en el log) ---"
G 'tail -5 /tmp/rt-dex/shell49.log 2>/dev/null; grep -c "SHELL_EXIT\|SIGKILL\|Segmentation" /tmp/rt-dex/shell49.log 2>/dev/null | head -1'

echo "--- 4. INTEGRIDAD: carga y memoria ahora ---"
G 'uptime; free -h 2>/dev/null | head -3'

echo "--- 5. TERRENO: espacio en disco del contenedor ---"
G 'df -h / 2>/dev/null | tail -1; df -h /tmp 2>/dev/null | tail -1'

echo "--- 6. TERRENO: salud de dpkg/apt (auditoria, sin cambios) ---"
G 'dpkg --audit 2>&1 | head -5; echo "audit_ok"
ls /var/lib/apt/lists/ 2>/dev/null | wc -l'

echo "--- 7. TERRENO: actualizando listas de paquetes (apt update, seguro) ---"
G 'apt-get update 2>&1 | tail -3'

echo "--- 8. TERRENO: que hay ya instalado (resumen) ---"
G 'dpkg -l 2>/dev/null | grep ^ii | wc -l; command -v synaptic apt flatpak snap 2>/dev/null'

echo "VEREDICTO: INTEGRIDAD_Y_TERRENO_MEDIDOS — datos arriba; nada destructivo ejecutado (solo apt update de listas). Listos para instalar apps."
echo "=== MISION-A31 COMPLETE ==="
echo "### BRIDGE MARKER ###"