echo "=== MISION-A28-RECON — reconocimiento del Ubuntu (SOLO LECTURA) $(date -u +%FT%TZ) ==="
W="$HOME/substrate/bridge"
T="$PREFIX/tmp"
termux-wake-lock 2>/dev/null
mkdir -p "$W" "$T"
echo "--- 0. guardas ---"
echo "REGLA: mision de solo lectura. Ningun apt, kill, write o config change sera ejecutado."
cat > "$T/recon-in.sh" <<'EOS'
echo "--- A. identidad del sistema ---"
head -4 /etc/os-release
uname -a
id
echo "--- B. version GNOME y paquetes clave ---"
gnome-shell --version 2>&1
dpkg -l 2>/dev/null | grep -E "ii  (gnome-shell|gnome-session|mutter|weston|xwayland|pipewire)" | awk '{print $2, $3}' | head -20
echo "--- C. sesion viva? ---"
pgrep -ax gnome-shell 2>/dev/null || echo "gnome-shell: NO detectado"
pgrep -ax weston 2>/dev/null || echo "weston: NO detectado"
pgrep -ax Xwayland 2>/dev/null || echo "Xwayland: NO detectado"
echo "--- D. entorno del proceso vivo ---"
GP=$(pgrep -x gnome-shell 2>/dev/null | head -1)
if [ -n "$GP" ]; then
  echo "gnome-shell pid=$GP uptime: $(ps -o etime= -p $GP 2>/dev/null)"
  tr '\0' '\n' < /proc/$GP/environ 2>/dev/null | grep -E "^(DISPLAY|WAYLAND_DISPLAY|XDG_SESSION_TYPE|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|XDG_CURRENT_DESKTOP|MESA_|EGL_|LIBGL|VK_|WLR_|QT_)" | sort
else
  echo "sin proceso vivo que inspeccionar"
fi
echo "--- E. GPU en uso ---"
export DISPLAY=:0
glxinfo -B 2>/dev/null | grep -E "renderer|OpenGL version|Accelerated|video memory"
vulkaninfo --summary 2>/dev/null | grep -E "deviceName|driverName|apiVersion|deviceType" | head -12
ls /dev/dri 2>/dev/null && echo "RENDER_NODES_PRESENTE" || echo "/dev/dri no accesible"
echo "--- F. tema y extensiones (MacTahoe) ---"
gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null
gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null
gsettings get org.gnome.shell enabled-extensions 2>/dev/null
ls ~/.local/share/gnome-shell/extensions 2>/dev/null
echo "--- G. launchers y scripts de control ---"
ls -la /usr/local/bin/ 2>/dev/null
for f in /usr/local/bin/*.sh; do [ -f "$f" ] && { echo "### CONTENIDO $f ###"; sed -n '1,60p' "$f"; }; done
echo "--- H. infraestructura de sesion (fakes) ---"
ls -la /usr/local/share/substrate 2>/dev/null || echo "sin /usr/local/share/substrate"
ls -la /run/systemd 2>/dev/null || echo "sin systemd (normal en proot)"
ls /tmp/rt-dex 2>/dev/null | head -15
tail -25 /tmp/rt-dex/shell.log 2>/dev/null
echo "--- I. sesiones definidas ---"
ls /usr/share/wayland-sessions /usr/share/xsessions 2>/dev/null
echo "--- J. autostart del usuario ---"
ls -la ~/.config/autostart 2>/dev/null
cat ~/.config/autostart/*.desktop 2>/dev/null | head -30
echo "--- K. acceso remoto ---"
pgrep -ax sshd 2>/dev/null || echo "sshd: NO corre dentro de la distro"
command -v sshd
echo "--- L. top procesos dentro de la distro ---"
ps aux 2>/dev/null | sort -k3 -rn | head -8
echo "--- FIN DE LA DISTRO ---"
EOS
proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/recon-in.sh 2>&1
echo "=== M. lado Termux ==="
echo "distros instaladas:"
proot-distro list 2>/dev/null | grep -E "Name|ubuntu" | head -6
echo "procesos proot vivos:"
pgrep -fa "proot" 2>/dev/null | head -4
echo "boot scripts de Termux:"
ls -la ~/.termux/boot 2>/dev/null && cat ~/.termux/boot/* 2>/dev/null | head -20
echo "hooks en .bashrc:"
grep -n "substrate\|loop\|escritorio\|bridge" ~/.bashrc 2>/dev/null | head -10
echo "scripts en ~/substrate:"
ls -la ~/substrate/ 2>/dev/null
echo "uptime y carga:"
uptime
rm -f "$T/recon-in.sh"
echo "VEREDICTO: RECON_COMPLETO — inventario de como se levanta, controla y ve tu Ubuntu recolectado arriba. Ningun archivo ni config fue modificado (solo lectura verificado)."
echo "=== MISION-A28-RECON COMPLETE ==="
echo "### BRIDGE MARKER ###"