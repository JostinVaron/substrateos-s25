# Apps, GPU, Blender y ArtCraft

## 1. Regla central

Hay dos rutas:

| Tipo de app | Cómo lanzarla | Render |
|---|---|---|
| GTK4/GTK3 de escritorio | dock, overview o `gnome-text-editor` | GTK4 `GSK_RENDERER=gl` sobre Zink/Turnip; compositor Zink |
| OpenGL/3D (Blender, ArtCraft, visores) | `substrate-gpu-run ...` | Zink sobre Turnip/kgsl, Adreno 830 |

El compositor y las apps comparten el mismo stack: **Zink sobre Turnip** (Vulkan)
usando `/dev/kgsl-3d0`. Ya no hay ruta freedreno-gallium ni compositor software
por defecto. Escape hatch: `GNOME49_SW=1 gnome49 --restart` vuelve a
llvmpipe/swrast + Cairo.

**No lanzar Blender desde el dock** si se quiere GPU: usa
`substrate-gpu-run blender` (el dock hereda el entorno, que ya es Zink, pero el
wrapper fija HOME/DBUS/audio correctos).

---

## 2. Apps GTK4

La sesión exporta:

```sh
GSK_RENDERER=gl        # ngl y cairo: ver nota de estabilidad
GTK_A11Y=none
NO_AT_BRIDGE=1
PULSE_SERVER=tcp:127.0.0.1:4713
```

Motivo:

- `GSK_RENDERER=ngl` reproducidamente mata el shell con SIGKILL al mapear la
  primera ventana GTK4 (I-01). `gl` sobre Zink sí es estable (3 editores +
  2 Widget Factory, y 10 min con Text Editor abierto).
- at-spi multiplica procesos (ibus, at-spi registry, gjs) y Android termina
  matando el árbol de la sesión. `GTK_A11Y=none` + `NO_AT_BRIDGE=1` lo evitan.
- El fallback `cairo` sigue disponible si una app GTK4 concreta falla.

Apps verificadas (compositor Zink, `GSK_RENDERER=gl`):

- **Text Editor** (`gnome-text-editor`) — abre/cierra, traffic lights.
- **Calculator** (`gnome-calculator`) — abre/cierra.
- **Widget Factory** (`gtk4-widget-factory`) — abre/cierra.
- **Nautilus** (Files) — abre; puede tener problemas si se lanza como root según el flujo.
- **gnome-terminal** — GTK3; abre.
- **LibreOffice** — abre desde dock; no es GTK4.

Si una app GTK4 falla:

```bash
GSK_RENDERER=cairo GTK_A11Y=none NO_AT_BRIDGE=1 app
```

y revisar `/tmp/rt-dex/shell49.log` (`SHELL_EXIT=137`).

---

## 3. GPU disponible

Prueba real:

```bash
substrate-gpu-run glxinfo -B
```

Resultado de esta máquina:

```
direct rendering: Yes
Device: zink Vulkan 1.4(Adreno (TM) 830v1 (MESA_TURNIP)) (0x44050001)
OpenGL renderer string: zink Vulkan 1.4(Adreno (TM) 830v1 (MESA_TURNIP))
OpenGL version string: 4.6 (Compatibility Profile) Mesa 26.3.0-devel
```

`substrate-gpu-run` hace:

```sh
DISPLAY=:0
HOME=/home/dexuser
XDG_RUNTIME_DIR=/tmp/rt-dex
GTK_A11Y=none
NO_AT_BRIDGE=1
PULSE_SERVER=tcp:127.0.0.1:4713
DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)
. /etc/profile.d/zz-adreno-gpu.sh
exec "$@"
```

La receta `zz-adreno-gpu.sh` (v4) es:

```sh
GALLIUM_DRIVER=zink
MESA_LOADER_DRIVER_OVERRIDE=zink
LIBGL_ALWAYS_SOFTWARE=0
MESA_VK_WSI_PRESENT_MODE=immediate
COGL_DISABLE_TFP=1   # I-11: sin DRI3, zink no puede importar pixmaps (TFP); CPU readback
```

**Por qué `COGL_DISABLE_TFP=1` (crítico, I-11):** Termux:X11 anuncia DRI3 pero
el open del dispositivo falla (`MESA-EGL: DRI3 error: Could not get DRI3 device`).
Mutter X11 compone las ventanas con GLX texture-from-pixmap; sin DRI3 la textura
queda vacía y **las apps se abren pero no se ven** (el escritorio sí). Con
`COGL_DISABLE_TFP=1` mutter lee cada ventana por CPU (XGetImage) en cada damage
y la compone igual: visibilidad pixel-exacta, idle 0% CPU, coste solo con
animación activa. **`proot-distro login` NO hereda env del host**: el knob debe ir
en `zz-adreno-gpu.sh` o `session-inner.sh`, nunca por entorno externo.

**Verificación de visibilidad OBLIGATORIA (`scripts/distro/test-visibilidad.sh`):**
nunca contar colores de la región (el wallpaper da 40k+ y produce falsos positivos).
El gate correcto compara pixel a pixel: `import -window $WID` vs `scrot` recortado
→ `compare -metric RMSE` = **0** y `AE` = **0**.

**Por qué Zink/Turnip:** el bug I-01 vivía en la ruta freedreno-gallium al
componer superficies ARGB de GTK4. Zink emite otro stream de comandos (Vulkan
Turnip) y no dispara el fallo. No se parcheó freedreno ni se trasplantó Mesa de
Termux: todo viene de `libgl1-mesa-dri` del distro (`kgsl_dri.so`,
`zink_dri.so`, Turnip).

Benchmark medido (glxgears, 1040x704):

| Estado | FPS | RSS shell | Colores captura |
|---|---|---|---|
| Antes (llvmpipe/swrast) | 475–490 | 326 MB | 90 268 |
| Después (Zink/Turnip) | 120 (vblank 120 Hz) | 242 MB | 93 315 |

---

## 4. Instalar Blender

Ubuntu 26.04 ofrece **Blender 5.0.1** en el repositorio actual (consultado: `apt-cache policy blender`). Instalación:

```bash
proot-distro login ubuntu-gnome --shared-tmp -- bash
apt update
apt install -y blender
```

Comprobar:

```bash
blender --version
```

Lanzar con GPU:

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc \
  'substrate-gpu-run blender'
```

### Qué esperar en Blender

- **UI, viewport, Eevee y Workbench:** deben usar OpenGL 4.6 vía freedreno. La app corre fuera del compositor, así que el fallback software del shell no la limita directamente.
- **Cycles:** la renderización GPU con CUDA/HIP/OpenCL **no está disponible** en Adreno. Cycles puede usar CPU. No prometer Cycles GPU.
- **Vulkan:** no se asume soporte estable; usar el backend OpenGL.
- **Addons y librerías:** instalar en `/home/dexuser`; evitar rutas de sistema.
- **Memoria:** 10 GiB visibles; escenas grandes pueden agotar RAM. Cerrar Firefox/otras apps.
- **Resolución:** 2000x1200; si el viewport va lento, reducir la ventana o usar Workbench.

### Diagnóstico de Blender

Dentro de Blender:

- `Help > System Information` debe mostrar el renderer **Adreno (TM) 830v1** y OpenGL 4.6.
- Si muestra llvmpipe, se lanzó desde el dock o sin `substrate-gpu-run`.

Fuera:

```bash
substrate-gpu-run glxinfo -B | grep -E 'renderer|version'
```

Si Blender cierra solo, revisar `dmesg`/logcat; no usar `pkill`.

---

## 5. Instalar ArtCraft y otras suites

No hay una instalación de ArtCraft verificada en esta máquina; la guía es deliberadamente genérica para no inventar rutas. Tratar ArtCraft como una app OpenGL:

1. Preferir **.deb** o **AppImage** oficial.
2. Evitar Flatpak/snap como primera opción: proot no es un entorno ideal para sandboxing y namespace.
3. Instalar dependencias nativas que pida (`libgl1`, `libegl1`, `libx11`, `libxkbcommon`, etc.).
4. Lanzar siempre con el wrapper GPU:

   ```bash
   chmod +x ArtCraft.AppImage
   substrate-gpu-run ./ArtCraft.AppImage
   ```

5. Si la app es GTK4 y además usa GL, evaluar:
   - primero `substrate-gpu-run`;
   - si el compositor se cae, volver a `GSK_RENDERER=cairo` y reportar la ruta.

### AppImage

```bash
mkdir -p /home/dexuser/Apps
cp ArtCraft.AppImage /home/dexuser/Apps/
chmod +x /home/dexuser/Apps/ArtCraft.AppImage
substrate-gpu-run /home/dexuser/Apps/ArtCraft.AppImage
```

Puede requerir `--appimage-extract-and-run` si FUSE no está disponible:

```bash
substrate-gpu-run /home/dexuser/Apps/ArtCraft.AppImage --appimage-extract-and-run
```

### .deb

```bash
apt install -y ./artcraft.deb
substrate-gpu-run artcraft
```

### Dependencias comunes

```bash
apt install -y libgl1 libegl1 libglx-mesa0 libx11-6 libxext6 \
  libxrender1 libxkbcommon0 libfontconfig1 libfreetype6 \
  libglib2.0-0 libgtk-3-0
```

Si la app necesita GTK4, añadir `libgtk-4-1`.

---

## 6. Crear un lanzador GPU en el escritorio

Para no escribir el comando cada vez, crear `~/.local/share/applications/blender-gpu.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Blender (GPU)
Exec=/usr/local/bin/substrate-gpu-run blender
Icon=blender
Terminal=false
Categories=Graphics;3DGraphics;
```

Actualizar:

```bash
update-desktop-database /home/dexuser/.local/share/applications 2>/dev/null || true
```

Luego se puede buscar “Blender (GPU)” en overview. **No usar el .desktop normal** si hereda el entorno software del dock.

---

## 7. Reglas para no romper la sesión

1. GTK4 con `GSK_RENDERER=gl`; **nunca `ngl`** (mata el shell). Si algo falla, `cairo`.
2. Mantener `GTK_A11Y=none` y `NO_AT_BRIDGE=1`: at-spi/ibus multiplican procesos
   y Android mata el árbol de la sesión.
3. No usar `pkill -f`; matar solo por PID de `/tmp/rt-dex/*.pid`.
4. Guardar los archivos antes de probar apps 3D pesadas.
5. Si el shell muere, `gnome49 --restart`; X sigue vivo.
6. Si una app 3D va lenta, comprobar que no está en llvmpipe (`glxinfo`).
7. No instalar servicios systemd esperando que arranquen solos.
8. Si el compositor Zink se vuelve inestable: `GNOME49_SW=1 gnome49 --restart`
   (vuelve a llvmpipe/swrast, el estado dorado anterior).

---

## 8. Rendimiento: expectativas honestas

- **Compositor Zink/Turnip:** 120 FPS vblank-locked, 242 MB RSS del shell,
  `kgsl_fds=1`, `zink`/`vulkan_freedreno` en `/proc/<pid>/maps`.
- **GPU apps:** usan Adreno real vía Zink; Blender 5.0.1 abrió ventana y se
  mantuvo 25 s sin SIGKILL.
- **CPU:** 8 núcleos; proot añade overhead de syscalls.
- **RAM:** 10 GiB; el escritorio + servicios + apps pueden dejar poco margen.
- **Benchmarks:** `glxgears` antes/después en `evidence/` y `docs/03`.

---

## 9. Checklist de una app GPU

- [ ] `substrate-gpu-run glxinfo -B` muestra Adreno.
- [ ] La app se lanza con `substrate-gpu-run`.
- [ ] No muestra llvmpipe en su panel de sistema.
- [ ] El shell sigue vivo al abrir/cerrar.
- [ ] El cierre es normal (botón o WM_DELETE), no `pkill`.
- [ ] Los datos se guardan en `/home/dexuser`.
