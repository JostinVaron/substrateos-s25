# SubstrateOS S25

**Ubuntu 26.04.1 LTS + GNOME Shell 49.0 sobre Termux/proot, con estética MacTahoe, en Samsung Galaxy S25 (Adreno 830).**

Este repositorio es la **identidad operativa** de la máquina: qué hay, cómo arranca, qué se modificó, qué está verificado, qué falla y cómo reconstruirla desde cero. Está pensado para que otra IA o una persona pueda entender el sistema sin haber estado en esta conversación.

> **Estado actual: compositor GPU Zink/Turnip estable.** GNOME Shell 49 compone en la Adreno 830 vía Zink sobre Turnip (`/dev/kgsl-3d0`), con 120 FPS vblank-locked, apps GTK4 en `GSK_RENDERER=gl` y **0 SIGKILL** en stress + soak + 10 min con ventana GTK4 abierta. El bug I-01 de freedreno-gallium con ARGB/GTK4 se rodea por diseño. Escape hatch software: `GNOME49_SW=1 gnome49 --restart`. Detalle en [`docs/05-ISSUES-ROADMAP.md`](docs/05-ISSUES-ROADMAP.md).

- Fecha de esta instantánea: **2026-11-17**
- Equipo: **Samsung Galaxy S25**, SoC Snapdragon 8 Elite, GPU **Adreno 830v1**
- Rootfs: contenedor proot-distro **`ubuntu-gnome`**
- X server: **Termux:X11** en `:0`
- Última sesión medida: `kgsl_fds=1`, `zink` ×4 en maps, `llvmpipe=0`, captura con **93 315–94 847 colores**
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
                          └─ gnome-shell --x11  (compositor Zink/Turnip)
                                ├─ GNOME Shell 49 + Ubuntu Dock + user-theme
                                ├─ MacTahoe: shell, GTK, iconos, wallpaper
                                └─ apps: GTK4 con GSK=gl sobre Zink; GPU vía substrate-gpu-run
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
| Compositor | Mutter, **Zink sobre Turnip (GPU real, kgsl)** |
| GPU | **Adreno 830v1**, Mesa **26.3.0-devel** (zink + turnip) |
| OpenGL/GLSL | **4.6 Compatibility**; GLES 3.2 |
| Memoria | 10 GiB totales (disponible observado: 3.8 GiB) |
| CPU visible | 8 núcleos |
| X | 2000x1200, `:0` |
| themes | MacTahoe-Dark, iconos MacTahoe-dark, wallpaper MacTahoe-day |
| Shell user | root dentro del proot (apps directas pueden ir como `dexuser`) |
| systemd | **no existe**; servicios en foreground + fake logind |

Detalle: [`docs/00-IDENTIDAD.md`](docs/00-IDENTIDAD.md).

### Cómo se resolvió I-01 (Zink/Turnip)

El compositor acelerado con **freedreno-gallium** moría con `SIGKILL` al mapear
una ventana **GTK4** (ARGB/CSD). Se probaron, sin éxito determinista:
`COGL_DISABLE_TFP`, `LIBGL_DRI3_DISABLE`, `COGL_DEBUG=...`,
`MUTTER_DEBUG_FORCE_LINEAR_BLENDING`, `FD_MESA_DEBUG=nolrz`, sesión `dexuser`,
sin bus, sin CSD, sin sombras.

La solución fue cambiar de ruta: **Zink sobre Turnip** emite otro stream de
comandos (Vulkan) y no dispara el bug.

```sh
# /etc/profile.d/zz-adreno-gpu.sh (v4)
GALLIUM_DRIVER=zink
MESA_LOADER_DRIVER_OVERRIDE=zink
LIBGL_ALWAYS_SOFTWARE=0
MESA_VK_WSI_PRESENT_MODE=immediate
# session-inner.sh
GSK_RENDERER=gl     # ngl mata el shell; cairo es fallback
GTK_A11Y=none
NO_AT_BRIDGE=1
```

Un `SIGKILL` que apareció durante el stress inicial **no era GPU**: Android mató
el árbol de la sesión por una explosión de procesos at-spi/ibus. Con a11y
desactivado desaparece. Resultados: 2 bloques de stress sin muertes, soak de
10 min, 10 min con GTK4 abierta, Blender 5.0.1 abierto, 120 FPS vblank-locked.

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
  termux/       gnome49, gnome49-stop, restart49.sh, substrate-audio-up,
                mactahoe-on/off
  distro/       session49.sh, session-inner.sh, zz-adreno-gpu.sh,
                zz-adreno-gpu.software.sh, substrate-gpu-run,
                substrate-brightness, upower-stub.py, fake-login1.py,
                nm-stub.py, gnome-moderno.sh, substrate-flashback.sh
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
6. **Para apps con GPU, usar `substrate-gpu-run`** (fija HOME, DBUS, audio y a11y).
7. **No `GSK_RENDERER=ngl`**: mata el shell. Usar `gl`; `cairo` como fallback.
8. **No `GNOME49_SW=1` salvo emergencia**: es el escape hatch a llvmpipe.

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
- Captura con **>90.000 colores** (últimas: 93 315, 94 137, 94 847).
- `kgsl_fds>=1` y `zink` en `/proc/<shell>/maps`; `llvmpipe=0`.
- Text Editor (GTK4) abre y cierra sin que el shell muera.
- `substrate-gpu-run glxinfo -B` muestra
  `zink Vulkan 1.4(Adreno (TM) 830v1 (MESA_TURNIP))` y GL 4.6.

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

- **App GTK4/GTK3 del escritorio:** abrir normal; llevan `GSK_RENDERER=gl`, `GTK_A11Y=none`, `NO_AT_BRIDGE=1`.
- **App que necesita OpenGL/GPU** (Blender, visores 3D, ArtCraft, etc.): lanzar con:

  ```bash
  proot-distro login ubuntu-gnome --shared-tmp -- bash -lc \
    'substrate-gpu-run blender'
  ```

`substrate-gpu-run` fija `DISPLAY`, `HOME`, `XDG_RUNTIME_DIR`, bus, audio TCP y
a11y, carga `/etc/profile.d/zz-adreno-gpu.sh` (Zink) y ejecuta la app.

Guía detallada, limitaciones de Cycles/OpenGL y pruebas: [`docs/03-APPS-GPU.md`](docs/03-APPS-GPU.md).

---

## Estado verificado en esta instantánea

| Prueba | Resultado |
|---|---|
| Arranque limpio `gnome49 --restart` | OK, sin ventanas de prueba |
| `gnome49 status` | Sesión activa, WM GNOME Shell OK, `kgsl_fds=1` |
| Captura con color | 93 315–94 847 colores |
| Compositor | Zink/Turnip, `llvmpipe=0`, `swrast=0` |
| Text Editor / Calculator / Widget Factory | OK con `GSK_RENDERER=gl` sobre Zink |
| Stress I-01 (2 bloques, 11 apps + arrastre + escritorios) | OK, 0 SIGKILL |
| Soak 10 min | `VIVO` |
| 10 min con Text Editor GTK4 abierta | `VIVO` |
| `xclock`, `zenity` | OK |
| Blender 5.0.1 (`substrate-gpu-run`) | Ventana mapeada, shell vivo |
| LibreOffice desde dock | Abre proceso; renderizado estable |
| `substrate-gpu-run glxinfo` | zink Vulkan 1.4 / Adreno 830v1, GL 4.6 |
| Audio | PulseAudio Termux + TCP loopback; `paplay` rc=0, volumen 50% |
| Batería | `upower-stub` con % real (56–58%, discharging) |
| Brillo | `substrate-brightness` 101→90→101; atajos Super+F1/F2 |
| GPU shell acelerado | **Estable** (I-01 cerrado) |

---

## Limitaciones conocidas

- **Compositor GPU Zink/Turnip** (I-01 cerrado). `ngl` sigue roto; usar `gl`. Escape hatch `GNOME49_SW=1`.
- **shell ejecutándose como root** dentro del proot: aparece la notificación “Logged in as a privileged user”. I-02 sigue abierto (ver roadmap).
- **Audio:** PulseAudio + TCP loopback funciona (slider y `paplay` rc=0); falta confirmación humana de audibilidad.
- **Bluetooth:** sin adaptador BlueZ ni `/dev/rfkill`; el tile no aparece.
- **Brillo/batería:** resueltos vía ADB (brillo) y `termux-battery-status` + stub UPower (batería).
- **Wi-Fi:** el tile muestra la red simulada `SubstrateOS`; el chevron del submenú sigue sin abrir en MacTahoe (CSS del tema).
- **DING** y **snapd-prompting** desactivados; escritorio limpio.
- **Apps Flatpak/snap** no son el camino recomendado; usar deb/AppImage.
- **Ciclos de render GPU en Blender** (Cycles con CUDA/HIP/OpenCL) no están soportados por Adreno; Eevee/Workbench y la UI sí pueden usar OpenGL.

---

## Licencia y aviso

Este repositorio documenta una configuración personal. Ubuntu, GNOME, Termux, MacTahoe y las apps mencionadas conservan sus licencias originales. No se distribuyen binarios de terceros ni credenciales.

**Si algo falla:** leer primero `docs/04-OPERACION-TESTS.md` y `docs/02-INSTALACION-LIMPIA.md`; después revisar `/tmp/rt-dex/shell49.log` y `session49-launch.log`. No borrar `/tmp/rt-dex` sin respaldar la sesión.
