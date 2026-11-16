# Arquitectura y funcionamiento

## 1. Cadena de arranque

```
[Android]
  └─ Termux app (nativo)
       ├─ termux-x11 :0  ← servidor X (Termux:X11)
       └─ gnome49
            └─ restart49.sh
                 ├─ verifica X con xdpyinfo
                 ├─ gnome49-stop
                 ├─ elimina proots de sesión y restos exactos
                 ├─ limpia pidfiles
                 ├─ arranca polkitd-helper
                 └─ proot-distro login ubuntu-gnome --shared-tmp
                      └─ bash /tmp/rt-dex/session49.sh
                           ├─ exporta entorno de sesión
                           ├─ fuente /etc/profile.d/zz-adreno-gpu.sh
                           ├─ prepara D-Bus de sistema dedicado
                           ├─ arranca fake-login1
                           ├─ arranca D-Bus de sesión con dbus-run-session
                           └─ bash /tmp/rt-dex/session-inner.sh
                                ├─ arranca gsd-* (power, media, xsettings, sound, ...)
                                ├─ arranca portales
                                ├─ ajusta gsettings MacTahoe
                                └─ gnome-shell (subshell con software)
```

Después de lanzar, `gnome49` espera:

1. que exista el PID del shell;
2. que GNOME Shell sea el WM (no solo un proceso);
3. que la captura de `scrot` supere un umbral de colores.

Si no se cumple, no declara éxito.

## 2. Archivos y rutas

### Termux nativo

| Ruta | Función |
|---|---|
| `$PREFIX/bin/gnome49` | launcher/estado/reinicio |
| `$PREFIX/bin/gnome49-stop` | parada segura |
| `$PREFIX/tmp/rt-dex/` | runtime compartido con el proot |
| `$PREFIX/tmp/rt-dex/restart49.sh` | reinicio y limpieza |
| `$PREFIX/tmp/rt-dex/session49.sh` | entorno de sesión |
| `$PREFIX/tmp/rt-dex/session-inner.sh` | arranque del shell y servicios |
| `$PREFIX/tmp/rt-dex/shell49.log` | stdout/stderr del shell y `SHELL_EXIT` |
| `$PREFIX/tmp/rt-dex/session49-launch.log` | log de arranque de la sesión |
| `$PREFIX/tmp/rt-dex/session-bus.addr` | dirección del bus de sesión |
| `$PREFIX/tmp/rt-dex/*.pid` | PIDs de servicios |
| `$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs/` | rootfs Ubuntu |
| `~/.local/share/substrate/rt-dex/` | respaldo persistente de scripts/evidencia |

### Dentro del proot

| Ruta | Función |
|---|---|
| `/tmp/rt-dex` | enlace compartido al runtime de Termux (`--shared-tmp`) |
| `/home/dexuser` | home lógico, themes y gsettings |
| `/etc/profile.d/zz-adreno-gpu.sh` | receta GPU Adreno |
| `/usr/local/bin/substrate-gpu-run` | wrapper de apps GPU |
| `/usr/local/share/substrate/fake-login1.py` | logind simulado |
| `/usr/local/share/substrate/nm-stub.py` | NetworkManager simulado |
| `/usr/share/icons/MacTahoe*` | iconos |
| `/home/dexuser/.themes/MacTahoe-*` | temas GTK/Shell |
| `/home/dexuser/.config/gtk-4.0/` | CSS y assets GTK4 |
| `/home/dexuser/.local/share/backgrounds/` | wallpapers |

## 3. Componentes y responsabilidades

### `gnome49`

- Verifica que `:0` responde.
- Espera estabilidad de resolución (evita arrancar mientras Termux:X11 redimensiona).
- Llama a `restart49.sh` o reutiliza la sesión existente.
- Aplica afinidad a núcleos prime (`taskset -apc 6-7`).
- Verifica WM y color.
- Mantiene `termux-wake-lock` y, si hay ADB inalámbrico, `stayon`/timeout.
- No abre ventanas de prueba.

### `restart49.sh`

- Requiere X vivo.
- Detiene la sesión anterior con `gnome49-stop`.
- Mata solo proots/cmdlines exactos de la sesión y restos conocidos.
- Limpia pidfiles.
- Arranca `polkitd-helper` (root) que espera el bus del sistema.
- Lanza `session49.sh` dentro del proot.
- Aplica afinidad al shell.

### `session49.sh`

- Exporta `HOME=/home/dexuser`, `USER=dexuser`, `DISPLAY=:0`, `XDG_*`.
- Carga la receta GPU.
- Define `DBUS_SYSTEM_BUS_ADDRESS` dedicado.
- Crea el bus de sistema con `dbus-daemon`.
- Arranca `fake-login1.py`.
- Lanza el bus de sesión con `dbus-run-session`.
- Ejecuta `session-inner.sh`.

### `session-inner.sh`

- Publica `session-bus.addr` y el symlink `$XDG_RUNTIME_DIR/bus`.
- Ajusta gsettings MacTahoe y wallpaper.
- Arranca `gnome-keyring-daemon` (secrets).
- Arranca `gsd-*`: power, media-keys, keyboard, xsettings, sound, housekeeping, a11y-settings, screensaver-proxy, color, datetime, rfkill.
- Arranca `xdg-desktop-portal` y `xdg-desktop-portal-gtk`.
- Desactiva DING y snapd-prompting.
- Conserva dock, appindicators, tiling-assistant y user-theme.
- Arranca `gnome-shell` en un subshell con **entorno software** y registra `SHELL_EXIT`.
- No ejecuta warmup salvo `RT_ENABLE_WARMUP=1` manual.

### `gnome49-stop`

- Detiene shell y servicios por PID exacto.
- No toca X, SSH, tmux, Termux, OpenCode ni `sv`.
- Conserva X para reiniciar rápido.

## 4. D-Bus

Hay dos buses:

1. **Sistema dedicado** en `/tmp/rt-dex/system-bus49`:
   - lo crea `session49.sh` con `system-dbus49.conf`;
   - `polkitd` se conecta a él;
   - evita depender del bus de Android.
2. **Sesión** creado por `dbus-run-session`:
   - su dirección se guarda en `session-bus.addr`;
   - apps y servicios del escritorio lo usan;
   - `substrate-gpu-run` lo exporta para apps externas.

El bus de sesión es necesario para portales, notificaciones, GApplication, keyring y activación D-Bus.

## 5. logind simulado

`/usr/local/share/substrate/fake-login1.py` implementa lo mínimo de `org.freedesktop.login1` para que GNOME Shell y apps crean que existe una sesión. No hay systemd. El archivo se arranca desde `session49.sh`.

## 6. Red simulada

`nm-stub.py` implementa `org.freedesktop.NetworkManager` y objetos asociados. La red `SubstrateOS` es una simulación de laboratorio, no la interfaz real de Android. El tile Wi-Fi de GNOME muestra esa red. El chevron del submenú no abre en el tema MacTahoe (ver issues).

## 7. GPU

### Receta base

`/etc/profile.d/zz-adreno-gpu.sh` contiene:

```sh
export LIBGL_ALWAYS_SOFTWARE=0
export GALLIUM_DRIVER=freedreno
export MESA_LOADER_DRIVER_OVERRIDE=kgsl
export FD_FORCE_KGSL=1
export FD_MESA_DEBUG=nolrz
export LIBGL_DRI3_DISABLE=1
```

Se carga automáticamente en shells de login dentro del proot. `session49.sh` la fuente y luego hace `unset LIBGL_DRI3_DISABLE` para el compositor (histórico). El compositor actual usa software por el fallback; las apps usan `substrate-gpu-run`.

### `substrate-gpu-run`

```sh
substrate-gpu-run blender
```

- fija `DISPLAY=:0`, `HOME=/home/dexuser`, `XDG_RUNTIME_DIR=/tmp/rt-dex`;
- toma `DBUS_SESSION_BUS_ADDRESS` del archivo de sesión;
- fuente `zz-adreno-gpu.sh`;
- quita `LIBGL_ALWAYS_SOFTWARE` (por si se heredó del shell software);
- `exec` de la app.

Es la vía recomendada para apps 3D.

## 8. Tema MacTahoe

- **GTK3/GTK4:** `/home/dexuser/.themes/MacTahoe-Dark/`.
- **Iconos:** `/usr/share/icons/MacTahoe-dark/`.
- **Shell:** extensión `user-theme` con nombre MacTahoe-Dark.
- **Dock:** Ubuntu Dock; parche `DO_NOT_AUTO_START` en `fileManager1API.js` para que no abra Nautilus automáticamente.
- **GTK4:** CSS y assets en `/home/dexuser/.config/gtk-4.0/`.
- **Traffic lights:** assets de ventanas; visibles en Text Editor, Calculator, Nautilus y Terminal.
- **Wallpaper:** `MacTahoe-day.jpeg` en `picture-uri` y `picture-uri-dark`.

## 9. Variables de entorno críticas

En sesión:

```
DISPLAY=:0
XDG_RUNTIME_DIR=/tmp/rt-dex
XDG_CURRENT_DESKTOP=ubuntu:GNOME
XDG_SESSION_TYPE=x11
GSK_RENDERER=cairo
GTK_A11Y=none
NO_AT_BRIDGE=1
FD_MESA_DEBUG=nolrz
```

En el subshell del compositor:

```
LIBGL_ALWAYS_SOFTWARE=1
GALLIUM_DRIVER=llvmpipe
MESA_LOADER_DRIVER_OVERRIDE=swrast
LIBGL_DRI3_DISABLE=1
```

En apps GPU:

```
LIBGL_ALWAYS_SOFTWARE=0
GALLIUM_DRIVER=freedreno
MESA_LOADER_DRIVER_OVERRIDE=kgsl
FD_FORCE_KGSL=1
FD_MESA_DEBUG=nolrz
```

## 10. Por qué no se usa systemd

proot no puede arrancar systemd como PID 1 real. Por eso:

- servicios en foreground/background con `setsid nohup`;
- PIDs guardados en `/tmp/rt-dex`;
- `fake-login1.py` cubre logind;
- no hay `systemctl`;
- no se deben instalar servicios que asuman systemd.

## 11. Flujo de una app del dock

1. El dock usa `GAppInfo` del `.desktop`.
2. Lanza el proceso como hijo del shell (root) y hereda el entorno del compositor software.
3. Si es GTK4, `GSK_RENDERER=cairo` evita GSK GL.
4. Si necesita OpenGL real, hay que lanzarla con `substrate-gpu-run` desde un terminal/sesión, no desde el dock, salvo que se cree un `.desktop` GPU específico.
5. El cierre se hace con el botón de la ventana o `xdotool windowclose`; nunca `pkill -f`.

## 12. Watchdogs y límites Android

Android puede matar procesos “phantom” si el monitor está activo. En esta máquina:

- `settings_enable_monitor_phantom_procs=false/0`;
- `max_phantom_processes=2147483647`;
- no se pudo fijar `persist.sys.fflag...` sin root;
- aun así, el fallo de GTK4 producía `SIGKILL` (137) en el shell. Se descartó OOM/LMKD/phantom como causa primaria; el detonante es la ruta GPU del compositor.

No usar Perfetto/perf para señales: sin root no se habilitan eventos `signal_generate`; el trace queda vacío.

## 13. Recuperación

- Si el shell muere: `gnome49 --restart`.
- Si X no responde: pedir a la persona que abra Termux:X11; luego `termux-x11` si hace falta.
- Si la UI está negra: revisar `/tmp/rt-dex/shell49.log` y `session49-launch.log`.
- Si una app GTK4 mata el shell: usar el compositor software actual; no volver a hardware sin leer issues.
- Si se borra `/tmp/rt-dex`: `gnome49` restaura scripts desde `~/.local/share/substrate/rt-dex/`.
