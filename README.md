# SubstrateOS S25

**Ubuntu 26.04.1 LTS + GNOME Shell 49.0 sobre Termux/proot, con estética MacTahoe, en Samsung Galaxy S25 (Adreno 830).**

Este repositorio es la **identidad operativa** de la máquina: qué hay, cómo arranca, qué se modificó, qué está verificado, qué falla y cómo reconstruirla desde cero. Está pensado para que otra IA o una persona pueda entender el sistema sin haber estado en esta conversación.

> **Estado actual: funcional y estable con compositor software.** La GPU Adreno 830 sí está disponible y verificada para aplicaciones OpenGL, pero el compositor de GNOME se dejó en llvmpipe porque el compositor acelerado con GTK4/ARGB terminaba en `SIGKILL` en pruebas reproducibles. Ver [Motivo del fallback](#motivo-del-fallback) y el roadmap.

- Fecha de esta instantánea: **2026-11-16**
- Equipo: **Samsung Galaxy S25**, SoC Snapdragon 8 Elite, GPU **Adreno 830v1**
- Rootfs: contenedor proot-distro **`ubuntu-gnome`**
- X server: **Termux:X11** en `:0`
- Última sesión medida: `gnome-shell` **PID 27693**, `kgsl_fds=0`, UI **2000x1200**, captura con **145651 colores**
- Evidencia: [`evidence/`](evidence/)

---

## Qué es y qué no es

**Es** una sesión de escritorio GNU/Linux real, dentro de Android, usando Termux nativo + proot-distro. Comparte el kernel y `/proc` con Android, pero no tiene systemd real ni acceso root al host.

**No es** una máquina virtual de virtualización por hardware, ni una instalación de Ubuntu que pueda arrancar sola. Es un **contenedor de usuarios proot** con un escritorio X11 completo.

No se debe usar `pkill -f`: proot comparte `/proc` con Termux/Android y un patrón amplio puede matar SSH, tmux, OpenCode o el propio Termux. Usar PIDs exactos de `/tmp/rt-dex/*.pid`.

---

## Arranque rápido

Requisitos, en este orden:

1. Tener **Termux** y la app **Termux:X11** instalados.
2. Abrir **Termux:X11** (es una app Android; solo la persona puede abrirla).
3. En Termux nativo, arrancar el servidor X si no está:

   ```bash
   nohup termux-x11 >/dev/null 2>&1 &
   sleep 12
   DISPLAY=:0 xdpyinfo >/dev/null && echo "X listo"
   ```

4. Arrancar el escritorio:

   ```bash
   gnome49
   ```

   La primera vez tarda unos **35 s**; el launcher verifica que el shell sea el WM y que la captura tenga color real antes de declarar éxito.

5. Estado, reinicio y parada:

   ```bash
   gnome49 status
   gnome49 --restart
   gnome49-stop
   ```

6. Captura manual:

   ```bash
   proot-distro login ubuntu-gnome --shared-tmp -- bash -c \
     'DISPLAY=:0 scrot -o /tmp/rt-dex/captura.png'
   ```

> `gnome49` mantiene `termux-wake-lock`, intenta fijar `screen_off_timeout`/`stayon` vía ADB inalámbrico si está disponible y espera a que la resolución de X sea estable antes de lanzar el shell.

---

## Arquitectura en una imagen

```
Termux:X11 (app Android)
        │  X11 :0
        ▼
Termux nativo
  └─ gnome49 / restart49.sh
        └─ proot-distro login ubuntu-gnome --shared-tmp
              └─ session49.sh
                    ├─ D-Bus de sistema dedicado
                    ├─ polkitd
                    ├─ fake-login1
                    ├─ dbus-run-session
                    └─ session-inner.sh
                          ├─ gsd-* (power, media-keys, xsettings, sound, ...)
                          ├─ xdg-desktop-portal + -gtk
                          ├─ gnome-keyring
                          └─ gnome-shell --x11  (compositor software)
                                ├─ GNOME Shell 49 + Ubuntu Dock + user-theme
                                ├─ MacTahoe: shell, GTK, iconos, wallpaper
                                └─ apps: GTK4 con Cairo; apps GPU vía substrate-gpu-run
```

Detalle completo: [`docs/01-ARQUITECTURA.md`](docs/01-ARQUITECTURA.md).

---

## Identidad de la máquina

| Dato | Valor |
|---|---|
| Host | Samsung Galaxy S25 |
| Kernel visible | `Linux 6.17.0-PRoot-Distro aarch64` |
| Distro | Ubuntu 26.04.1 LTS (proot) |
| Escritorio | GNOME Shell 49.0, X11 |
| Compositor | Mutter, **software/llvmpipe en la sesión actual** |
| GPU | **Adreno 830v1**, Mesa **26.3.0-devel** |
| OpenGL/GLSL | **4.6 Core / 4.60**; GLES 3.2 |
| Memoria | 10 GiB totales (disponible observado: 3.8 GiB) |
| CPU visible | 8 núcleos |
| X | 2000x1200, `:0` |
| themes | MacTahoe-Dark, iconos MacTahoe-dark, wallpaper MacTahoe-day |
| Shell user | root dentro del proot (apps directas pueden ir como `dexuser`) |
| systemd | **no existe**; servicios en foreground + fake logind |

Detalle: [`docs/00-IDENTIDAD.md`](docs/00-IDENTIDAD.md).

### Motivo del fallback

El compositor acelerado (freedreno/kgsl) funciona para `xclock`, GTK3, LibreOffice y `glxinfo` (Adreno OpenGL 4.6), pero al mapear una ventana **GTK4** (Text Editor, Calculator, Widget Factory) el `gnome-shell` recibía **`SIGKILL` (137)** a los 2–60 s. Probamos, entre otras cosas:

- `COGL_DISABLE_TFP=1`
- `GSK_RENDERER=cairo` + `GTK_A11Y=none` + `NO_AT_BRIDGE=1`
- `LIBGL_DRI3_DISABLE=1`
- `COGL_DEBUG=disable-shared-atlas,disable-batching,disable-atlas,disable-pbos,disable-software-clip`
- `COGL_DEBUG=disable-offscreen`
- `MUTTER_DEBUG_FORCE_LINEAR_BLENDING=1`
- `FD_MESA_DEBUG=nolrz`
- sesión completa como `dexuser`, app en proot separado, sin bus, sin CSD, sin sombra CSS

`FD_MESA_DEBUG=nolrz` (desactivar LRZ) mejoró la supervivencia y permitió sesiones de 30–60 s con GTK4, pero **no fue determinista**. La solución estable elegida es **compositor software**; las apps OpenGL siguen usando la GPU por separado mediante `substrate-gpu-run`. El fallo residual y el camino para recuperar hardware están en [`docs/05-ISSUES-ROADMAP.md`](docs/05-ISSUES-ROADMAP.md).

---

## Estructura del repositorio

```
README.md
FINAL-STATUS.md
docs/
  00-IDENTIDAD.md
  01-ARQUITECTURA.md
  02-INSTALACION-LIMPIA.md
  03-APPS-GPU.md
  04-OPERACION-TESTS.md
  05-ISSUES-ROADMAP.md
  06-REFERENCIA-RAPIDA.md
scripts/
  termux/       gnome49, gnome49-stop, restart49.sh, mactahoe-on/off
  distro/       session49.sh, session-inner.sh, zz-adreno-gpu.sh,
                substrate-gpu-run, fake-login1.py, nm-stub.py,
                gnome-moderno.sh, substrate-flashback.sh
patches/
evidence/
```

Los scripts son **copias de la configuración funcional** de esta máquina, no una maqueta. Cualquier cambio debe probarse en la sesión y volver a copiar aquí.

---

## Reglas de oro

1. **No `pkill -f`.** Usar PIDs exactos. Nunca matar `sshd`, `tmux`, `termux`, `node`, `opencode`, `sv`.
2. **No correr servicios del escritorio desde Termux nativo.** Todo lo del escritorio vive dentro del proot.
3. **No reiniciar Termux:X11** si ya está sirviendo `:0`; se perdería la sesión. Si el servidor X no responde, se pide a la persona que abra la app.
4. **No declarar éxito por “proceso vivo”.** Éxito = shell + WM + captura con color + app que abre y cierra.
5. **Guardar PIDs/estado en `/tmp/rt-dex/` antes de cualquier prueba destructiva.**
6. **Para apps con GPU, no confiar en el entorno del dock:** el shell está en software. Usar `substrate-gpu-run`.

---

## Verificación mínima

```bash
gnome49 status

proot-distro login ubuntu-gnome --shared-tmp -- bash -lc \
  'DISPLAY=:0 xdpyinfo >/dev/null && echo X_OK'

proot-distro login ubuntu-gnome --shared-tmp -- bash -lc \
  'DISPLAY=:0 scrot -o /tmp/rt-dex/check.png && \
   python3 -c "from PIL import Image; im=Image.open(\"/tmp/rt-dex/check.png\").convert(\"RGB\"); print(len(im.getcolors(maxcolors=10000000)))"'
```

Criterios usados en esta máquina:

- `gnome49 status` muestra `WM: GNOME Shell OK`.
- Captura con **>100.000 colores** (la última: 145.651).
- Text Editor (GTK4) abre y cierra sin que el shell muera.
- `substrate-gpu-run glxinfo -B` muestra `Adreno (TM) 830v1` y OpenGL 4.6.

---

## Instalación desde cero

La guía completa, con paquetes, permisos, usuarios, themes, fake logind, GPU y comprobaciones, está en:

- [`docs/02-INSTALACION-LIMPIA.md`](docs/02-INSTALACION-LIMPIA.md)

Resumen:

1. Instalar Termux:X11 y proot-distro.
2. Crear/restaurar el contenedor `ubuntu-gnome`.
3. Instalar GNOME 49 y dependencias.
4. Copiar `scripts/` a las rutas reales.
5. Restaurar themes/iconos/wallpaper y gsettings.
6. Ejecutar `termux-x11` y `gnome49`.
7. Verificar con `gnome49 status`, captura y una app GTK4.

---

## Apps, Blender y ArtCraft

La regla es:

- **App GTK4/GTK3 del escritorio:** abrir normal; ya llevan `GSK_RENDERER=cairo`, `GTK_A11Y=none`, `NO_AT_BRIDGE=1`.
- **App que necesita OpenGL/GPU** (Blender, visores 3D, ArtCraft, etc.): lanzar con:

  ```bash
  proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc \
    'substrate-gpu-run blender'
  ```

`substrate-gpu-run` exporta la sesión, carga `/etc/profile.d/zz-adreno-gpu.sh` y fuerza hardware (`freedreno/kgsl`, `FD_MESA_DEBUG=nolrz`), evitando el llvmpipe del compositor.

Guía detallada, limitaciones de Cycles/OpenGL y pruebas: [`docs/03-APPS-GPU.md`](docs/03-APPS-GPU.md).

---

## Estado verificado en esta instantánea

| Prueba | Resultado |
|---|---|
| Arranque limpio `gnome49 --restart` | OK, sin ventanas de prueba |
| `gnome49 status` | Sesión activa, WM GNOME Shell OK |
| Captura con color | 145.651 colores |
| Text Editor GTK4 abre/cierra | OK con shell software, 30 s + cierre |
| Calculator GTK4 | OK en pruebas de shell software |
| Widget Factory GTK4 | OK con hardware + `nolrz` durante 60 s (modo experimental) |
| `xclock`, `zenity` | OK con hardware |
| LibreOffice desde dock | Abre proceso; renderizado estable |
| Idle 120 s | Shell y UI sobreviven |
| `substrate-gpu-run glxinfo` | Adreno 830v1, OpenGL 4.6 |
| GPU shell acelerado | **No estable** con GTK4; ver roadmap |

---

## Limitaciones conocidas

- **Compositor software** por el fallo LRZ/ARGB descrito. El escritorio es estable, pero no es la máxima aceleración posible.
- **shell ejecutándose como root** dentro del proot: aparece la notificación “Logged in as a privileged user”. Las apps lanzadas directamente como `dexuser` evitan parte del problema, pero el shell sigue siendo root.
- **Audio/volumen:** PipeWire entra en bucle `ENOSYS` en proot; no hay slider de volumen.
- **Bluetooth:** sin adaptador BlueZ ni `/dev/rfkill`; el tile no aparece.
- **Brillo/batería:** sin hardware/backlight accesible desde el proot.
- **Wi-Fi:** el tile muestra la red simulada `SubstrateOS`; el chevron del submenú no abre en MacTahoe.
- **DING** y **snapd-prompting** desactivados; escritorio limpio.
- **Apps Flatpak/snap** no son el camino recomendado; usar deb/AppImage.
- **Ciclos de render GPU en Blender** (Cycles con CUDA/HIP/OpenCL) no están soportados por Adreno; Eevee/Workbench y la UI sí pueden usar OpenGL.

---

## Licencia y aviso

Este repositorio documenta una configuración personal. Ubuntu, GNOME, Termux, MacTahoe y las apps mencionadas conservan sus licencias originales. No se distribuyen binarios de terceros ni credenciales.

**Si algo falla:** leer primero `docs/04-OPERACION-TESTS.md` y `docs/02-INSTALACION-LIMPIA.md`; después revisar `/tmp/rt-dex/shell49.log` y `session49-launch.log`. No borrar `/tmp/rt-dex` sin respaldar la sesión.
