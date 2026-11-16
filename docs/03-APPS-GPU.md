# Apps, GPU, Blender y ArtCraft

## 1. Regla central

Hay dos rutas:

| Tipo de app | Cómo lanzarla | Render |
|---|---|---|
| GTK4/GTK3 de escritorio | dock, overview o `gnome-text-editor` | GTK4 con `GSK_RENDERER=cairo`; compositor software |
| OpenGL/3D (Blender, ArtCraft, visores) | `substrate-gpu-run ...` | freedreno/kgsl, Adreno 830 |

**No lanzar Blender desde el dock** con el entorno actual: heredaría `LIBGL_ALWAYS_SOFTWARE=1` del compositor y usaría llvmpipe. Lanzarlo desde un login `dexuser` con `substrate-gpu-run`.

---

## 2. Apps GTK4

La sesión exporta:

```sh
GSK_RENDERER=cairo
GTK_A11Y=none
NO_AT_BRIDGE=1
```

Motivo:

- GSK GL/EGL en GTK4 disparaba el fallo del compositor Adreno al mapear la primera ventana.
- at-spi podía tumbar el shell bajo proot.
- Cairo mantiene GTK4 funcional y oscuro con MacTahoe.

Apps verificadas:

- **Text Editor** (`gnome-text-editor`) — abre/cierra, traffic lights.
- **Calculator** (`gnome-calculator`) — abre/cierra.
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
Device: Adreno (TM) 830v1 (0xffffffff)
Video memory: 11113MB
OpenGL renderer string: Adreno (TM) 830v1
OpenGL core profile version string: 4.6 (Core Profile) Mesa 26.3.0-devel
OpenGL core profile shading language version string: 4.60
OpenGL ES profile version string: OpenGL ES 3.2
```

`substrate-gpu-run` hace:

```sh
DISPLAY=:0
HOME=/home/dexuser
XDG_RUNTIME_DIR=/tmp/rt-dex
DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)
. /etc/profile.d/zz-adreno-gpu.sh
unset LIBGL_ALWAYS_SOFTWARE
exec "$@"
```

La receta `zz-adreno-gpu.sh` incluye:

```sh
LIBGL_ALWAYS_SOFTWARE=0
GALLIUM_DRIVER=freedreno
MESA_LOADER_DRIVER_OVERRIDE=kgsl
FD_FORCE_KGSL=1
FD_MESA_DEBUG=nolrz
LIBGL_DRI3_DISABLE=1
```

`FD_MESA_DEBUG=nolrz` desactiva LRZ, que fue el detonante más probable del fallo ARGB/GTK4. Para apps 3D se mantiene; el compositor estable no lo usa porque corre software.

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

1. Abrir GTK4 con Cairo.
2. No poner el compositor en freedreno con GTK4 hasta resolver el fallo de LRZ/ARGB.
3. No usar `pkill -f`.
4. Guardar los archivos antes de probar apps 3D pesadas.
5. Si el shell muere, `gnome49 --restart`; X sigue vivo.
6. Si una app 3D va lenta, comprobar que no está en llvmpipe (`glxinfo`).
7. No instalar servicios systemd esperando que arranquen solos.

---

## 8. Rendimiento: expectativas honestas

- **Compositor software:** estable, pero el escritorio a 2000x1200 no es la vía de máximo rendimiento. Es el precio de evitar el SIGKILL.
- **GPU apps:** usan Adreno real; Blender/Eevee/Workbench pueden beneficiarse.
- **CPU:** 8 núcleos; proot añade overhead de syscalls.
- **RAM:** 10 GiB; el escritorio + servicios + apps pueden dejar poco margen. Cerrar apps no usadas.
- **No hay benchmarks FPS formales en este repo**; `glxinfo` y las capturas son la evidencia disponible. Añadir benchmarks es parte del roadmap.

---

## 9. Checklist de una app GPU

- [ ] `substrate-gpu-run glxinfo -B` muestra Adreno.
- [ ] La app se lanza con `substrate-gpu-run`.
- [ ] No muestra llvmpipe en su panel de sistema.
- [ ] El shell sigue vivo al abrir/cerrar.
- [ ] El cierre es normal (botón o WM_DELETE), no `pkill`.
- [ ] Los datos se guardan en `/home/dexuser`.
