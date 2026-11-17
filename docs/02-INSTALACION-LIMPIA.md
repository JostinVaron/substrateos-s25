# Instalación limpia / reconstrucción

Esta guía reconstruye **SubstrateOS S25** en un Galaxy S25 (o dispositivo ARM64 compatible) desde Termux. Está separada en dos caminos:

- **A. Restaurar sobre un contenedor Ubuntu 26.04 existente** (recomendado; conserva paquetes y themes).
- **B. Desde cero absoluto** (rootfs nuevo; más lento y con más puntos de fallo).

> **Antes de empezar:** respaldar `/home/dexuser`, `/usr/share/icons/MacTahoe*`, `/home/dexuser/.themes`, `/home/dexuser/.config/gtk-4.0`, `/home/dexuser/.local/share/backgrounds` y `/etc/profile.d/zz-adreno-gpu.sh`. Sin esos assets no se reproduce MacTahoe.

---

## 0. Requisitos

### Android

- Samsung Galaxy S25 (o ARM64 con Termux compatible).
- **Termux** (F-Droid o GitHub; evitar la versión obsoleta de Play Store).
- **Termux:X11** (app Android).
- Opcional: **Shizuku** para ajustes que no requieren root; no se usa para root real.
- Espacio libre: **≥ 12 GB** (rootfs + GNOME + apps).
- Conexión a Internet para `apt`.

### Termux

```bash
pkg update
pkg upgrade -y
pkg install -y proot-distro termux-x11-nightly x11-repo
```

`x11-repo` provee herramientas X11. Si `termux-x11-nightly` no existe en el repositorio, instalar el paquete equivalente de Termux:X11 y abrir la app.

### Comprobaciones

```bash
uname -m                  # aarch64
echo "$PREFIX"            # /data/data/com.termux/files/usr
proot-distro --version
```

---

## 1. Crear/restaurar el contenedor `ubuntu-gnome`

### 1.1 Si ya existe

```bash
proot-distro list
proot-distro login ubuntu-gnome --shared-tmp -- bash -lc 'cat /etc/os-release'
```

Debe decir **Ubuntu 26.04.1 LTS**. Si el contenedor se llama `ubuntu`, hay dos opciones:

- renombrar el directorio:

  ```bash
  mv "$PREFIX/var/lib/proot-distro/containers/ubuntu" \
     "$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome"
  ```

- o ajustar todos los scripts para usar `ubuntu` (no recomendado; rompe rutas y documentación).

### 1.2 Contenedor nuevo

```bash
proot-distro install ubuntu
# El alias instala una base Ubuntu; renombrar al nombre que esperan los scripts:
mv "$PREFIX/var/lib/proot-distro/containers/ubuntu" \
   "$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome"
```

> El contenedor de referencia fue creado con una base Ubuntu 26.04.1 y luego se instaló el escritorio GNOME. La versión exacta de paquetes puede cambiar con el tiempo; por eso los scripts se versionan aquí.

### 1.3 Rootfs esperado

```
$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs
```

---

## 2. Instalar GNOME 49 y dependencias

Dentro del contenedor:

```bash
proot-distro login ubuntu-gnome --shared-tmp -- bash
```

Actualizar:

```bash
apt update
apt upgrade -y
```

Instalar escritorio y utilidades (Ubuntu 26.04):

```bash
DEBIAN_FRONTEND=noninteractive apt install -y \
  ubuntu-desktop-minimal \
  gnome-shell gnome-session gnome-settings-daemon mutter \
  gnome-terminal nautilus gnome-text-editor gnome-calculator \
  gnome-keyring gnome-control-center \
  dbus dbus-x11 polkitd \
  xdg-desktop-portal xdg-desktop-portal-gtk \
  network-manager \
  mesa-utils libgl1-mesa-dri libegl-mesa0 \
  x11-utils x11-xserver-utils xdotool wmctrl scrot \
  python3 python3-pil \
  fonts-dejavu fonts-noto-color-emoji \
  adwaita-icon-theme
```

Notas:

- `ubuntu-desktop-minimal` ya arrastra buena parte de GNOME; si el metapaquete intenta instalar servicios systemd, se instalan pero **no se usan**.
- **No** se necesita `snapd` ni `flatpak` para este escritorio.
- Si `ubuntu-desktop-minimal` falla por dependencias de sistema, usar `apt install gnome-shell gnome-session ...` con la lista de arriba.
- Verificar versiones:

```bash
gnome-shell --version      # GNOME Shell 49.0
cat /etc/os-release
```

---

## 3. Crear el usuario lógico `dexuser`

El sistema actual usa `HOME=/home/dexuser` y `USER=dexuser` aunque el shell corra como root dentro del proot.

```bash
id dexuser || useradd -m -s /bin/bash dexuser
install -d -m 700 /home/dexuser
```

Comprobar:

```bash
ls -ld /home/dexuser
```

Restaurar el home desde el respaldo (themes, `.config`, backgrounds) si existe.

---

## 4. Copiar scripts

Desde Termux nativo, con el repo en `~/substrateos-s25`:

```bash
REPO="$HOME/substrateos-s25"
ROOT="$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs"

# Termux
install -m 755 "$REPO/scripts/termux/gnome49"       "$PREFIX/bin/gnome49"
install -m 755 "$REPO/scripts/termux/gnome49-stop"  "$PREFIX/bin/gnome49-stop"
install -m 755 "$REPO/scripts/termux/mactahoe-on"   "$PREFIX/bin/mactahoe-on" 2>/dev/null || true
install -m 755 "$REPO/scripts/termux/mactahoe-off"  "$PREFIX/bin/mactahoe-off" 2>/dev/null || true

# Runtime /tmp (se puede restaurar; los scripts persistentes están en el repo)
install -d -m 700 "$PREFIX/tmp/rt-dex"
install -m 755 "$REPO/scripts/termux/restart49.sh"   "$PREFIX/tmp/rt-dex/restart49.sh"
install -m 755 "$REPO/scripts/distro/session49.sh"   "$PREFIX/tmp/rt-dex/session49.sh"
install -m 755 "$REPO/scripts/distro/session-inner.sh" "$PREFIX/tmp/rt-dex/session-inner.sh"

# Rootfs
install -m 755 "$REPO/scripts/distro/zz-adreno-gpu.sh" \
  "$ROOT/etc/profile.d/zz-adreno-gpu.sh"
install -m 755 "$REPO/scripts/distro/substrate-gpu-run" \
  "$ROOT/usr/local/bin/substrate-gpu-run"
install -d "$ROOT/usr/local/share/substrate"
install -m 755 "$REPO/scripts/distro/fake-login1.py" \
  "$ROOT/usr/local/share/substrate/fake-login1.py"
install -m 755 "$REPO/scripts/distro/nm-stub.py" \
  "$ROOT/usr/local/share/substrate/nm-stub.py"
```

### Respaldos persistentes

`gnome49` puede restaurar scripts que falten en `/tmp/rt-dex` desde:

```
~/.local/share/substrate/rt-dex/
```

Copiar allí la versión funcional:

```bash
mkdir -p "$HOME/.local/share/substrate/rt-dex"
cp -a "$PREFIX/tmp/rt-dex/session49.sh" \
      "$PREFIX/tmp/rt-dex/session-inner.sh" \
      "$PREFIX/tmp/rt-dex/restart49.sh" \
      "$HOME/.local/share/substrate/rt-dex/"
```

> No borrar `/tmp/rt-dex` sin comprobar que el respaldo está actualizado.

---

## 5. Permisos de `/tmp/rt-dex`

El runtime debe ser accesible por los procesos del proot y por las apps lanzadas como `dexuser`:

```bash
chmod 700 "$PREFIX/tmp/rt-dex"
# solo si se prueba una sesión como dexuser, puede necesitarse:
# chmod -R a+rwX "$PREFIX/tmp/rt-dex"
```

En la configuración estable actual el shell es root y `dexuser` se usa para apps directas; los permisos `700` son suficientes para el arranque, pero `substrate-gpu-run` necesita leer `session-bus.addr` y `DISPLAY`. Si una app como `dexuser` no puede leer el bus, ajustar permisos de forma controlada.

---

## 6. Themes, iconos y wallpaper

Los assets no se versionan completos por tamaño; se restauran desde el respaldo del dispositivo:

```
/home/dexuser/.themes/MacTahoe-Dark/
/home/dexuser/.themes/MacTahoe-Light/
/home/dexuser/.themes/MacTahoe-Dark-hdpi/
/home/dexuser/.themes/MacTahoe-Dark-xhdpi/
/usr/share/icons/MacTahoe/
/usr/share/icons/MacTahoe-dark/
/usr/share/icons/MacTahoe-light/
/home/dexuser/.config/gtk-4.0/gtk.css          (symlink a gtk-Dark.css)
/home/dexuser/.config/gtk-4.0/gtk-Dark.css
/home/dexuser/.config/gtk-4.0/windows-assets/
/home/dexuser/.local/share/backgrounds/MacTahoe-day.jpeg
/home/dexuser/.local/share/backgrounds/MacTahoe-night.jpeg
```

Comprobar que `gtk.css` apunta a `gtk-Dark.css`:

```bash
ls -l /home/dexuser/.config/gtk-4.0/gtk.css
```

Configurar:

```bash
export HOME=/home/dexuser
gsettings set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark"
gsettings set org.gnome.desktop.wm.preferences theme "MacTahoe-Dark"
gsettings set org.gnome.desktop.interface icon-theme "MacTahoe-dark"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
gsettings set org.gnome.desktop.background picture-uri \
  "file:///home/dexuser/.local/share/backgrounds/MacTahoe-day.jpeg"
gsettings set org.gnome.desktop.background picture-uri-dark \
  "file:///home/dexuser/.local/share/backgrounds/MacTahoe-day.jpeg"
```

La sesión (`session-inner.sh`) repite estos `gsettings` en cada arranque para que las apps lanzadas por dock/overview hereden MacTahoe.

### Shell theme

La extensión `user-theme@gnome-shell-extensions.gcampax.github.com` debe estar habilitada y el nombre de tema apuntar a `MacTahoe-Dark`. Si no aparece el tema del panel/dock, ejecutar `mactahoe-on` o revisar:

```bash
gsettings get org.gnome.shell enabled-extensions
gsettings get org.gnome.shell.extensions.user-theme name
```

---

## 7. Extensiones y parches

- **Ubuntu Dock** activo; parche `DO_NOT_AUTO_START` en:
  `/usr/share/gnome-shell/extensions/ubuntu-dock@ubuntu.com/fileManager1API.js`
  Evita que el dock abra Nautilus al iniciar y mantiene el escritorio limpio.
- **DING** (`ding@rastersoft.com`) desactivado.
- **snapd-prompting** desactivado.
- **user-theme** habilitado.
- **appindicators**, **tiling-assistant** conservados.

Comandos:

```bash
gsettings get org.gnome.shell disabled-extensions
gsettings set org.gnome.shell disabled-extensions \
  "['ding@rastersoft.com', 'snapd-prompting@canonical.com']"
```

No desactivar `user-theme` ni `ubuntu-dock` si se quiere la estética de referencia.

---

## 8. Fake logind, bus de sistema y red simulada

`session49.sh` ya crea:

- bus de sistema en `/tmp/rt-dex/system-bus49`;
- `fake-login1.py`;
- bus de sesión;
- `polkitd` vía helper.

No ejecutar `systemctl`. No se necesita `systemd-logind`.

`nm-stub.py` debe estar en `/usr/local/share/substrate/` si se quiere el tile Wi-Fi simulado. La sesión actual lo usa para mostrar `SubstrateOS`.

---

## 9. GPU: receta Zink/Turnip y escape hatch

`/etc/profile.d/zz-adreno-gpu.sh` oficial (v4, **congelada**):

```sh
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export LIBGL_ALWAYS_SOFTWARE=0
export MESA_VK_WSI_PRESENT_MODE=immediate
export COGL_DISABLE_TFP=1   # I-11: sin DRI3, zink no importa pixmaps (TFP)
```

`session49.sh` fuente este archivo y limpia restos freedreno. El subshell del
compositor en `session-inner.sh` usa el mismo perfil Zink. Para volver al estado
software: `GNOME49_SW=1 gnome49 --restart` (usa
`/tmp/rt-dex/zz-adreno-gpu.software.sh`):

```sh
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export LIBGL_DRI3_DISABLE=1
```

Verificar GPU:

```bash
substrate-gpu-run glxinfo -B
```

Debe mostrar `Adreno (TM) 830v1`.

---

## 10. Arrancar X y GNOME

### X

Abrir la app **Termux:X11** desde Android. Si el servidor no está arriba:

```bash
nohup termux-x11 >/dev/null 2>&1 &
sleep 12
DISPLAY=:0 xdpyinfo >/dev/null && echo X_OK
```

### Sesión

```bash
gnome49
```

Esperar ~35 s. No abrir apps mientras el launcher aún verifica.

### Verificación

```bash
gnome49 status
DISPLAY=:0 xdpyinfo | head
```

Criterio de éxito:

- `WM: GNOME Shell OK`;
- `kgsl_fds>=1` (compositor en GPU; `0` solo en el escape hatch software);
- captura con color (>100.000 colores);
- **visibilidad real**: `test-visibilidad.sh xlogo` → `RMSE=0` (ver docs/04 §13);
- Text Editor abre/cierra sin matar el shell y **se ve** (no basta el conteo de colores).

---

## 11. Prueba de apps

GTK4:

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc '
  export HOME=/home/dexuser DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex
  export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)
  export GSK_RENDERER=gl GTK_A11Y=none NO_AT_BRIDGE=1
  exec gnome-text-editor
'
```

Cerrar:

```bash
proot-distro login ubuntu-gnome --shared-tmp -- bash -lc '
  DISPLAY=:0 xdotool search --name "Text Editor" windowclose
'
```

GPU:

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc \
  'substrate-gpu-run glxinfo -B'
```

Nunca cerrar con `pkill -f`.

---

## 12. Problemas típicos de instalación

| Síntoma | Causa probable | Acción |
|---|---|---|
| `X no responde` | Termux:X11 no está abierto o `termux-x11` no arrancó | abrir app; `termux-x11`; `xdpyinfo` |
| Shell arranca sin UI | Mutter/GL/DBus | `gnome49 --restart`; revisar logs |
| Shell muere al abrir GTK4 | `GSK_RENDERER=ngl` o pico at-spi | usar `gl` + `GTK_A11Y=none`; `cairo` fallback |
| Apps sin tema MacTahoe | gsettings/dconf en HOME incorrecto | `HOME=/home/dexuser`; ejecutar gsettings |
| `kgsl_fds=0` | compositor en software (`GNOME49_SW=1`) | quitar GNOME49_SW |
| `SHELL_EXIT=137` | SIGKILL Android (a11y/GPU) | revisar logcat y `docs/05`; escape hatch software |
| Audio ENOSYS | PipeWire bajo proot | usar `substrate-audio-up` (PulseAudio TCP) |
| Sin brillo/batería | stub/ADB no arrancó | `substrate-audio-up`; revisar `upowerd.log` |
| Bluetooth ausente | sin `/dev/rfkill` | limitación |
| App no abre como root | política de la app | lanzar con `--user dexuser` |
| D-Bus no encontrado | sesión no arrancada | `cat /tmp/rt-dex/session-bus.addr` |

---

## 13. Restauración rápida si `/tmp` se borra

`gnome49` restaura los scripts desde `~/.local/share/substrate/rt-dex/`. Si también se borró:

1. Reinstalar/copiar `scripts/` del repo a las rutas de la sección 4.
2. Recrear `/tmp/rt-dex` con permisos.
3. `gnome49 --restart`.

---

## 14. Checklist final

- [ ] Ubuntu 26.04.1 dentro de `ubuntu-gnome`.
- [ ] GNOME Shell 49.0.
- [ ] `dexuser` con home y themes.
- [ ] `gnome49`, `gnome49-stop`, `restart49.sh`, `session49.sh`, `session-inner.sh`.
- [ ] `zz-adreno-gpu.sh` y `substrate-gpu-run`.
- [ ] fake-login1 y nm-stub.
- [ ] MacTahoe GTK/iconos/wallpaper.
- [ ] extensión user-theme y dock.
- [ ] X `:0`.
- [ ] `gnome49 status` OK.
- [ ] captura con color.
- [ ] Text Editor abre/cierra.
- [ ] `substrate-gpu-run glxinfo -B` Adreno.
- [ ] sin audio/Bluetooth esperados.
