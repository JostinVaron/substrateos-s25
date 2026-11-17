# Identidad del sistema

## 1. Resumen

SubstrateOS S25 es una sesión Ubuntu 26.04.1 LTS con GNOME Shell 49.0 ejecutada en un contenedor **proot-distro** dentro de Termux, sobre un **Samsung Galaxy S25** (Snapdragon 8 Elite, Adreno 830v1). La pantalla se sirve por **Termux:X11** en `:0`.

No hay virtualización: los procesos comparten el kernel Android/Linux `6.17.0-PRoot-Distro` y el árbol `/proc`. proot intercepta syscalls para simular rootfs, UIDs y rutas. Esto permite un escritorio GNU/Linux real sin root del dispositivo, pero impone límites:

- no hay systemd real;
- no hay acceso root al host Android;
- algunos dispositivos (`/dev/rfkill`, backlight, audio) no existen;
- las llamadas que proot no emula pueden fallar con `ENOSYS`;
- `pkill -f` es peligroso porque también ve los procesos de Termux/Android.

## 2. Hardware y límites

| Elemento | Observación |
|---|---|
| Equipo | Samsung Galaxy S25 |
| SoC | Snapdragon 8 Elite |
| GPU | Adreno 830v1, driver **Zink sobre Turnip (Vulkan) vía kgsl** |
| RAM visible | 10 GiB |
| CPU visible | 8 núcleos |
| Pantalla X actual | 2000x1200 |
| GPU OpenGL | 4.6 Core, GLSL 4.60, GLES 3.2 |
| Mesa | 26.3.0-devel (`git-98f3d6229d`) |
| Almacenamiento | rootfs proot bajo Termux |

`glxinfo -B` real:

```
direct rendering: Yes
Device: Adreno (TM) 830v1 (0xffffffff)
Video memory: 11113MB
OpenGL renderer string: Adreno (TM) 830v1
OpenGL core profile version string: 4.6 (Core Profile) Mesa 26.3.0-devel
OpenGL core profile shading language version string: 4.60
OpenGL ES profile version string: OpenGL ES 3.2
```

## 3. Software

| Capa | Versión / ruta |
|---|---|
| Android | Termux nativo + Termux:X11 |
| proot | proot-distro |
| Distro | Ubuntu 26.04.1 LTS |
| Escritorio | GNOME Shell 49.0, Mutter X11 |
| Tema shell/GTK | MacTahoe-Dark |
| Iconos | MacTahoe-dark |
| Wallpaper | MacTahoe-day.jpeg |
| Comunicación | D-Bus de sistema dedicado + D-Bus de sesión |
| Login | `fake-login1.py` (no systemd/logind real) |
| Red | `nm-stub.py` (NetworkManager simulado) |
| Compositor actual | **Zink sobre Turnip (Adreno 830, kgsl)** |
| GPU para apps | Zink/Turnip (mismo stack que el compositor) |

## 4. Modelo de usuarios

- El **shell** se ejecuta como **root dentro del proot**. Por eso GNOME muestra “Logged in as a privileged user”.
- El entorno lógico usa `HOME=/home/dexuser`, `USER=dexuser`, `LOGNAME=dexuser`.
- Las apps que se lanzan con `proot-distro login ... --user dexuser` corren como `dexuser` dentro del rootfs.
- El shell y el dock pueden lanzar apps como root. Eso funciona para muchas apps, pero puede provocar diferencias de tema, permisos o rechazo de apps que no aceptan root (por ejemplo, Nautilus en algunos flujos).
- **No cambiar el shell a `dexuser` sin volver a probar D-Bus, X y lanzamiento de apps.** En una prueba, la sesión como `dexuser` arrancó pero Text Editor no mapeó ventana; se revirtió a root. Ver roadmap.

## 5. Modelo de rendering

Hay dos planos distintos:

### 5.1 Compositor

El shell usa **GPU real vía Zink sobre Turnip**:

```
GALLIUM_DRIVER=zink
MESA_LOADER_DRIVER_OVERRIDE=zink
LIBGL_ALWAYS_SOFTWARE=0
MESA_VK_WSI_PRESENT_MODE=immediate
```

`gnome49 status` debe mostrar `kgsl_fds>=1` y `zink` en
`/proc/<pid>/maps`. Escape hatch: `GNOME49_SW=1 gnome49 --restart` vuelve a
llvmpipe/swrast (perfil `zz-adreno-gpu.software.sh`).

### 5.2 Apps

`/etc/profile.d/zz-adreno-gpu.sh` (v4) exporta el mismo stack Zink/Turnip.
Para apps GTK4: `GSK_RENDERER=gl`, `GTK_A11Y=none`, `NO_AT_BRIDGE=1`
(`ngl` mata el shell; `cairo` es fallback).

`substrate-gpu-run` fija HOME/DBUS/audio/a11y, carga el perfil y lanza la app.
Así Blender/ArtCraft/visores 3D usan la Adreno.

## 6. Identidad visual

- Tema GTK: `org.gnome.desktop.interface gtk-theme = MacTahoe-Dark`
- Tema WM: `org.gnome.desktop.wm.preferences theme = MacTahoe-Dark`
- Iconos: `icon-theme = MacTahoe-dark`
- Color scheme: `prefer-dark`
- Wallpaper: `picture-uri` y `picture-uri-dark` apuntan a `MacTahoe-day.jpeg` para mantener la referencia visual.
- Traffic lights: assets en `/home/dexuser/.config/gtk-4.0/windows-assets/`.
- Dock flotante: extensión Ubuntu Dock, parcheada para no autolanzar el gestor de archivos.
- Shell theme: extensión `user-theme@gnome-shell-extensions.gcampax.github.com`.

## 7. Qué hace especial a esta instalación

1. **No es Ubuntu estándar:** es un rootfs proot dentro de Android. No hay GRUB, systemd, logind real ni kernel propio.
2. **Se sirve por X11**, no por Wayland directo. Termux:X11 actúa como servidor X.
3. **El compositor es software** por un fallo de estabilidad con GTK4/ARGB en Adreno.
4. **La GPU sigue existiendo** para apps OpenGL; el fallback no inutiliza la Adreno.
5. **Los scripts de arranque son propios** (`gnome49`, `restart49.sh`, `session49.sh`, `session-inner.sh`).
6. **Hay servicios simulados** (`fake-login1`, `nm-stub`) para que GNOME crea que existe un escritorio estándar.
7. **El tema MacTahoe** no es solo un wallpaper: incluye GTK3/GTK4, iconos, shell, dock y decoraciones.
8. **Está pensado para sobrevivir** a cierres de sesión, idle y reinicios del shell sin tocar Termux/SSH/OpenCode.

## 8. Lo que no hay

- systemd, journald, logind real.
- Audio funcional (PipeWire entra en `ENOSYS`).
- Bluetooth.
- Control de brillo/batería desde el proot.
- GPU Cycles/CUDA/HIP en Blender.
- Snap/Flatpak como vía principal (proot no es el entorno ideal para sandboxes).
- Notificación de root suprimida.

## 9. Estado actual

- Sesión estable con compositor **Zink/Turnip** (GPU real).
- Apps GTK4 con `GSK_RENDERER=gl`; GPU 3D vía `substrate-gpu-run`.
- Tema MacTahoe oscuro y wallpaper diurno restaurados.
- Captura final con 93 315–94 847 colores.
- Documento de estado: `FINAL-STATUS.md`.
