# FINAL STATUS — SubstrateOS S25

**Fecha:** 2026-11-16  
**Estado:** sesión GNOME 49 X11 activa, estable, compositor software, apps GTK4 verificadas.  
**No dejar procesos de prueba abiertos.**

## Sesión actual

| Campo | Valor |
|---|---|
| `gnome-shell` | PID **27693** (volátil; comprobar con `gnome49 status`) |
| X | `:0`, 2000x1200 |
| WM | GNOME Shell OK |
| `kgsl_fds` | **0** (compositor software) |
| `LIBGL_ALWAYS_SOFTWARE` | `1` en el proceso del shell |
| `GALLIUM_DRIVER` | `llvmpipe` en el shell |
| `MESA_LOADER_DRIVER_OVERRIDE` | `swrast` en el shell |
| Shell user | root dentro del proot |
| Home lógico | `/home/dexuser` |
| Tema | MacTahoe-Dark; iconos MacTahoe-dark; wallpaper MacTahoe-day |
| Captura | 145.651 colores |
| Ventanas de prueba | ninguna |

## Comandos

```bash
gnome49            # arranca / garantiza sesión
gnome49 status     # estado + WM + ventanas
gnome49 --restart  # reinicia completo (X intacto)
gnome49-stop       # detiene sesión; conserva X
```

## Qué se verificó

- Arranque limpio, sin apps automáticas.
- Shell y WM reales; captura con >100.000 colores.
- Text Editor GTK4 abre, permanece 30 s y cierra con el shell vivo.
- Calculator GTK4 y Widget Factory GTK4 estables en pruebas controladas.
- Widget Factory GTK4 abre 60 s con hardware + `FD_MESA_DEBUG=nolrz` (modo experimental).
- `xclock`, `zenity` y LibreOffice abren con hardware.
- Idle 120 s mantiene shell y UI.
- `substrate-gpu-run glxinfo -B`: Adreno 830v1, Mesa 26.3.0-devel, OpenGL 4.6.
- Cierre de app con `xdotool ... windowclose`; no usar `pkill -f`.

## Decisión técnica

El compositor acelerado con GTK4 ARGB → `SIGKILL` del shell (Android/GPU). `FD_MESA_DEBUG=nolrz` mejoró pero no eliminó el fallo. Se eligió **compositor software** para garantizar estabilidad. Las apps que necesitan OpenGL usan hardware por separado:

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc \
  'substrate-gpu-run blender'
```

## Limitaciones abiertas

- Notificación “Logged in as a privileged user” (shell root).
- Sin audio/volumen, Bluetooth, brillo ni batería real.
- Wi-Fi simulado `SubstrateOS`; chevron del submenú no abre.
- GPU acelerada del compositor: experimental, no por defecto.
- Blender: OpenGL/Eevee/Workbench; Cycles GPU no soportado por Adreno.

## Evidencia

- `evidence/01-editor-dark-software-shell.png`
- `evidence/02-escritorio-limpio.png`
- `evidence/03-widgetfactory-hardware-nolrz.png`
- `evidence/04-editor-software.png`
- `evidence/05-calculator-software.png`

## Si hay que recuperar

1. Leer `docs/04-OPERACION-TESTS.md`.
2. `gnome49 status`; si no hay sesión, `gnome49 --restart`.
3. Si X no responde, pedir a la persona que abra Termux:X11 y ejecutar `termux-x11` en Termux.
4. No borrar `/tmp/rt-dex`; los scripts se restauran desde `~/.local/share/substrate/rt-dex/`.
5. Para reinstalación completa: `docs/02-INSTALACION-LIMPIA.md`.

## Respaldos

- Scripts persistentes: `~/.local/share/substrate/rt-dex/`
- Rootfs: `/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu-gnome/rootfs`
- Repositorio: este directorio.
