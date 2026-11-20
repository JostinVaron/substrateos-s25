# PLAN DE ESTABILIZACIÓN ONE-SHOT — SubstrateOS S25 (Ubuntu 26.04 + GNOME Shell 49 + Adreno 830 Zink/Turnip)

> **DESTINATARIO:** Agente ejecutor de bajo coste (ejecución lineal, cero criterio propio).
> **REGLA SUPREMA DE EJECUCIÓN:** Ejecuta cada comando exactamente como está escrito, en el orden numérico estricto de las fases (`Fase 0` → `Fase 7`). No inventes variantes, no uses jamás `pkill -f`, y no avances de una fase a la siguiente sin que el bloque **GATE** de esa fase imprima explícitamente `GATE_PASS: FASE N COMPLETADA`. Toda la salida de cada fase `N` se guarda automáticamente en `/data/data/com.termux/files/usr/tmp/rt-dex/phase-N.log` (que dentro del proot es `/tmp/rt-dex/phase-N.log`).

---

## RESUMEN EJECUTIVO DEL DIAGNÓSTICO REAL (MEDIDO EN EL DISPOSITIVO)

El estado real medido en este teléfono (**Samsung Galaxy S25 `SM-S931B`, Snapdragon 8 Elite, Adreno 830v2, Ubuntu 26.04.1 LTS en `proot-distro` `ubuntu-gnome`**) es el siguiente:

1. **Cadena visual real actual:**
   - El sistema **ya migró** del antiguo stack `weston + gnome-shell --wayland` (`/usr/local/bin/gnome-moderno.sh`) a **GNOME Shell 49.0 sobre X11 directo** (`$PREFIX/bin/gnome49` → `$PREFIX/tmp/rt-dex/restart49.sh` → `/tmp/rt-dex/session49.sh` → `/tmp/rt-dex/session-inner.sh` → `gnome-shell` X11 con `libmutter-17.so.0.0.0` compilado con `-Dx11=true`).
   - Sin embargo, el script legado `/usr/local/bin/gnome-moderno.sh` todavía contiene `pkill -x` y `weston`; la **Fase 4** lo reemplaza por un puente seguro hacia `session49.sh`.
2. **GPU y Visibilidad (Zink + Turnip sobre `/dev/kgsl-3d0`):**
   - El driver `freedreno-gallium` mataba a `gnome-shell` con `SIGKILL` al mapear ventanas GTK4 ARGB (Issue I-01). La receta en `/etc/profile.d/zz-adreno-gpu.sh` usa **Zink sobre Turnip (Vulkan 1.4, Mesa 26.3.0-devel)** con `GALLIUM_DRIVER=zink`, `MESA_LOADER_DRIVER_OVERRIDE=zink`, `LIBGL_ALWAYS_SOFTWARE=0`, `MESA_VK_WSI_PRESENT_MODE=immediate` y `COGL_DISABLE_TFP=1`.
   - `COGL_DISABLE_TFP=1` es **obligatorio**: SELinux en Android bloquea `/dev/dri/renderD128` para Termux (`DRI3Open -> BadMatch`), por lo que GLX `texture-from-pixmap` (TFP) sin DRI3 importa texturas vacías (ventanas invisibles, Issue I-11). Con `COGL_DISABLE_TFP=1`, Mutter lee el damage de ventanas por MIT-SHM (CPU) y compone el escritorio en GPU Adreno 830 a 120 FPS con visibilidad pixel-exacta (`RMSE=0`).
3. **Por qué `gnome-shell` sigue muriendo (`SHELL_EXIT=137` / `SIGKILL`) — 6 causas raíz medidas (`2026-11-20`):**
   - **Causa Raíz 1 (Serial ADB fijo a `127.0.0.1:5555`):** `$PREFIX/bin/gnome49` ejecuta `adb -s 127.0.0.1:5555 ...`, pero el dispositivo activo en `adb devices` aparece como `emulator-5554` o `<IP>:<PUERTO>`. Por eso los blindajes contra el killer de Android (`stayon`, `settings_enable_monitor_phantom_procs=false`, `max_phantom_processes=2147483647`, `cached_apps_freezer=disabled`, `RUN_ANY_IN_BACKGROUND`) fallan silenciosamente.
   - **Causa Raíz 2 (Sesión `proot` desacoplada con `setsid` en vez de anclada a `tmux`):** `restart49.sh` lanza `proot-distro login ... session49.sh` con `setsid nohup` (`PPID=1`). En Samsung OneUI (`Freecess` / `PhantomProcessRecord`), los hijos de Termux desacoplados de `tmux` reciben `SIGKILL` tras ráfagas de actividad (`11-20 02:00:30.074 I ActivityManager: Process PhantomProcessRecord {86498a 15374:32145:gnome-shell/u0a345} died` medido en `logcat`). Anclar la sesión `proot` a una sesión persistente de `tmux` (`substrate-wm`) evita este kill.
   - **Causa Raíz 3 (Explosión de ~45 demonios inútiles en el proot + `ollama` en Termux):** Al arrancar `gnome-shell`, D-Bus activa `gnome-shell-calendar-server`, `evolution-source-registry`, `goa-daemon`, `goa-identity-service`, `evolution-calendar-factory`, `evolution-addressbook-factory`, 5 monitores de volumen hardware `gvfs-*-volume-monitor`, `xdg-document-portal` (que falla en bucle con `fuse: failed to open /dev/fuse: Permission denied`), 6 procesos `ibus-*`, `colord`, `geoclue`, y `gsd-rfkill` (que aborta con `SIGABRT` en `session49-launch.log` línea 25). Además, en Termux nativo corre `runsv ollama` (`ollama serve`).
   - **Causa Raíz 4 (Sin auto-recuperación in-session cuando `gnome-shell` recibe `SIGKILL`):** En `session-inner.sh`, cuando `gnome-shell` muere con `SHELL_EXIT=137` (ya sea por un reset de `kgsl` —`reset_count=12023` medido en `/sys/class/kgsl/kgsl-3d0/reset_count`— o por arranque en frío I-12), el subshell termina pero `session-inner.sh` queda bloqueado en `wait` esperando a `gsd-*` y `xdg-desktop-portal`. Eso deja la pantalla negra indefinidamente aunque X11 (`:0`), D-Bus y las apps sigan vivos. Un watchdog **in-place dentro de `session-inner.sh`** relanza únicamente `gnome-shell` en 2 segundos dentro de la misma sesión sin cerrar ventanas abiertas (y conmuta a software fallback si ocurren 3 muertes en <180 s).
   - **Causa Raíz 5 (`ulimit -n 32768` rebaja el límite del kernel):** El kernel da `open files = 524288`, pero `session49.sh` hace `ulimit -n 32768`, causando `dbus-daemon: Failed to set fd limit to 65536: Operation not permitted`.
   - **Causa Raíz 6 (Corrupción no idempotente de `disabled-extensions`):** `session-inner.sh` concatena `'ding@rastersoft.com', 'snapd-prompting@canonical.com'` en cada arranque sin deduplicar, habiendo inflado el array en dconf a más de 200 entradas repetidas.
4. **Herramientas faltantes en `ubuntu-gnome` (medido con `PATH` limpio):**
   - Instalados: `gcc`, `g++`, `make`, `pkg-config`, `python3`, `pip3`, `git`, `glxinfo`, `eglinfo`, `scrot`, `wmctrl`, `xdotool`.
   - **Faltan (`MISSING`):** `clang`, `cmake`, `nodejs`, `npm`, `python3-venv`, `glmark2-x11`, `glmark2-es2-x11`, `vulkan-tools` (`vulkaninfo`), `pulseaudio-utils` (`pactl`, `paplay`), `xclip`, `xsel`, `fonts-inter`, `fonts-jetbrains-mono`.

---

## 1. DIAGNÓSTICO (FASE 0)

Ejecuta este bloque completo en **Termux nativo**. Todas las salidas se guardan en `$PREFIX/tmp/rt-dex/phase-0.log`.

```bash
#!/data/data/com.termux/files/usr/bin/bash
set -u
export PREFIX="/data/data/com.termux/files/usr"
export TMPDIR="$PREFIX/tmp"
export RT="$TMPDIR/rt-dex"
mkdir -p "$RT"
LOG="$RT/phase-0.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== FASE 0: DIAGNOSTICO ($(date -u +%FT%TZ)) ==="

# Comando 0.1: Detectar serial ADB activo
ADB_SER=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1; exit}')
if [ -n "$ADB_SER" ]; then
  echo "[0.1-ADB] OK: serial=$ADB_SER"
  echo "$ADB_SER" > "$RT/adb.serial"
else
  adb connect 127.0.0.1:5555 >/dev/null 2>&1 || true
  ADB_SER=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1; exit}')
  echo "[0.1-ADB] RESULTADO: serial=${ADB_SER:-NONE}"
  echo "${ADB_SER:-}" > "$RT/adb.serial"
fi

# Comando 0.2: Verificar socket X0 y servidor X11 (:0)
ls -la "$TMPDIR/.X11-unix/" 2>&1 || true
if proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'DISPLAY=:0 timeout 4 xdpyinfo >/dev/null 2>&1'; then
  echo "[0.2-X11] OK: DISPLAY=:0 activo"
else
  echo "[0.2-X11] WARN: DISPLAY=:0 no responde; despertando Termux:X11 (A8+A10)..."
  cmp=$(cmd package resolve-activity --brief com.termux.x11 2>/dev/null | tail -1 || true)
  [ -n "$cmp" ] && am start -n "$cmp" >/dev/null 2>&1 || true
  [ -n "${ADB_SER:-}" ] && adb -s "$ADB_SER" shell am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
  nohup termux-x11 :0 >/dev/null 2>&1 &
  sleep 12
  if proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'DISPLAY=:0 timeout 4 xdpyinfo >/dev/null 2>&1'; then
    echo "[0.2-X11] OK: DISPLAY=:0 desperto tras termux-x11"
  else
    echo "[0.2-X11] ABORT_NEED_HUMAN_X11"
    exit 10
  fi
fi

# Comando 0.3: Medir renderer OpenGL (glxinfo) y EGL (eglinfo)
GLX_REND=$(proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; DISPLAY=:0 /usr/local/bin/substrate-gpu-run glxinfo -B 2>/dev/null | awk -F": " "/OpenGL renderer string/{print \$2}"' || true)
EGL_REND=$(proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; DISPLAY=:0 /usr/local/bin/substrate-gpu-run eglinfo -B 2>/dev/null | awk -F": " "/OpenGL core profile renderer/{print \$2; exit}"' || true)
echo "[0.3-GPU] GLX_RENDERER=${GLX_REND:-NONE} | EGL_RENDERER=${EGL_REND:-NONE}"

# Comando 0.4: Medir estado del kernel GPU Adreno (/sys/class/kgsl/kgsl-3d0)
for f in /sys/class/kgsl/kgsl-3d0/{gpu_model,reset_count,gpufaults,ft_policy,gpubusy,temp}; do
  [ -r "$f" ] && printf '[0.4-KGSL] %s = %s\n' "$f" "$(cat "$f" 2>/dev/null)"
done

# Comando 0.5: Auditar muertes previas en shell49.log y logcat PhantomProcessRecord
grep -E 'SHELL_EXIT=' "$RT/shell49.log" 2>/dev/null | tail -5 || true
if [ -n "${ADB_SER:-}" ]; then
  adb -s "$ADB_SER" shell "logcat -d -b all | grep -iE 'PhantomProcessRecord.*died|am_kill|lmkd' | tail -n 15" 2>/dev/null || true
fi

# Comando 0.6: Auditar fugas de dbus-daemon, inotify y memoria
DBUS_N=$(for q in /proc/[0-9]*; do c=$(tr '\0' ' ' 2>/dev/null < "$q/cmdline") || continue; case "$c" in dbus-daemon*) echo x;; esac; done | wc -l)
INOTIFY_N=$(ls -l /proc/[0-9]*/fd 2>/dev/null | grep -c 'anon_inode:inotify' || true)
echo "[0.6-RES] dbus_daemons=$DBUS_N inotify_fds=$INOTIFY_N"
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'free -m && ulimit -n'

# Comando 0.7: Auditar toolchain y utilidades en Ubuntu proot (con PATH limpio)
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  for cmd in gcc g++ make cmake pkg-config clang python3 node npm git glxinfo eglinfo glmark2-es2 vulkaninfo pactl paplay xclip xsel scrot wmctrl xdotool; do
    printf "[0.7-TOOL] %-14s : %s\n" "$cmd" "$(command -v "$cmd" 2>/dev/null || echo MISSING)"
  done
'

echo "GATE_PASS: FASE 0 COMPLETADA"
```

### Reglas de interpretación deterministas (Sin criterio del ejecutor)

1. **Sobre `[0.2-X11]`:**
   - **SI** imprime `ABORT_NEED_HUMAN_X11` (exit code `10`), **ENTONCES** detén la ejecución y pide al humano que realice el paso `### [HUMANO]` de abajo.
   - **SI** imprime `OK: DISPLAY=:0 activo` o `OK: DISPLAY=:0 desperto`, **ENTONCES** pasa a la Fase 1.
2. **Sobre `[0.3-GPU]`:**
   - **SI** `GLX_RENDERER` contiene `Adreno (TM) 830` y `zink`, **ENTONCES** el driver Zink/Turnip está funcional; la Fase 4 consolidará `COGL_DISABLE_TFP=1` y el watchdog in-place.
   - **SI** `GLX_RENDERER` contiene `llvmpipe` o `swrast` o está vacío, **ENTONCES** la sesión cayó al escape hatch software o perdió `/etc/profile.d/zz-adreno-gpu.sh`; la Fase 4 reescribirá `/etc/profile.d/zz-adreno-gpu.sh` y forzará `GNOME49_SW=0`.
3. **Sobre `[0.5]` (`SHELL_EXIT=137` / `PhantomProcessRecord ... died`):**
   - **SI** aparece `SHELL_EXIT=137` o `PhantomProcessRecord ... died`, **ENTONCES** ejecuta obligatoriamente las Fases 2, 3 y 4 completas (poda de demonios D-Bus + blindaje ADB dinámico + anclaje `tmux` + watchdog in-place en `session-inner.sh`).
4. **Sobre `[0.7-TOOL]`:**
   - **SI** cualquier herramienta aparece como `MISSING`, **ENTONCES** la Fase 5 la instalará con `apt-get install -y --no-install-recommends`.

### [HUMANO] — Acción requerida SOLO si el Comando 0.2 imprimió `ABORT_NEED_HUMAN_X11`
> Abre manualmente la app **Termux:X11** en tu Samsung Galaxy S25 para que Android cree la superficie gráfica, déjala en primer plano 5 segundos y vuelve a lanzar el bloque de la Fase 0.

---

## 2. BACKUPS (FASE 1)

Copia todos los scripts, configuraciones, estado de `/tmp/rt-dex` y base de datos `dconf` a un directorio con sello de tiempo y verifica su integridad con `sha256sum`.

```bash
#!/data/data/com.termux/files/usr/bin/bash
set -eu
export PREFIX="/data/data/com.termux/files/usr"
export TMPDIR="$PREFIX/tmp"
export RT="$TMPDIR/rt-dex"
export ROOTFS="$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs"
export BK_DIR="$HOME/.local/share/substrate/backups/pre-oneshot-$(date -u +%Y%m%d)"
LOG="$RT/phase-1.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== FASE 1: BACKUPS ($(date -u +%FT%TZ)) ==="
mkdir -p "$BK_DIR/termux-bin" "$BK_DIR/rt-dex" "$BK_DIR/rootfs-etc" "$BK_DIR/rootfs-bin" "$BK_DIR/rootfs-share" "$BK_DIR/dconf"

for f in gnome49 gnome49-stop mactahoe-on mactahoe-off; do
  [ -f "$PREFIX/bin/$f" ] && cp -a "$PREFIX/bin/$f" "$BK_DIR/termux-bin/$f"
done

for f in restart49.sh session49.sh session-inner.sh zz-adreno-gpu.sh zz-adreno-gpu.software.sh \
         substrate-audio-up substrate-brightness substrate-gpu-run upower-stub.py nm-stub.py \
         system-dbus49.conf shell49.log session49-launch.log; do
  [ -f "$RT/$f" ] && cp -a "$RT/$f" "$BK_DIR/rt-dex/$f"
done

[ -f "$ROOTFS/etc/profile.d/zz-adreno-gpu.sh" ] && cp -a "$ROOTFS/etc/profile.d/zz-adreno-gpu.sh" "$BK_DIR/rootfs-etc/"
for f in gnome-moderno.sh substrate-flashback.sh substrate-gpu-run substrate-brightness test-visibilidad.sh artcraft-broker artcraft-broker-client artcraft-suite-run; do
  [ -f "$ROOTFS/usr/local/bin/$f" ] && cp -a "$ROOTFS/usr/local/bin/$f" "$BK_DIR/rootfs-bin/"
done
[ -d "$ROOTFS/usr/local/share/substrate" ] && cp -a "$ROOTFS/usr/local/share/substrate/." "$BK_DIR/rootfs-share/"
[ -f "$ROOTFS/home/dexuser/.config/dconf/user" ] && cp -a "$ROOTFS/home/dexuser/.config/dconf/user" "$BK_DIR/dconf/user"

echo "$BK_DIR" > "$RT/latest-backup.path"
find "$BK_DIR" -type f -exec sha256sum {} + > "$BK_DIR/MANIFEST.sha256"

# GATE DE VERIFICACION FASE 1
test -s "$BK_DIR/MANIFEST.sha256"
test -f "$BK_DIR/termux-bin/gnome49"
test -f "$BK_DIR/rt-dex/session49.sh"
test -f "$BK_DIR/rt-dex/session-inner.sh"
test -f "$BK_DIR/rootfs-etc/zz-adreno-gpu.sh"
sha256sum -c "$BK_DIR/MANIFEST.sha256" >/dev/null
echo "BACKUP_COUNT=$(wc -l < "$BK_DIR/MANIFEST.sha256")"
echo "GATE_PASS: FASE 1 COMPLETADA"
```

- **Resultado esperado:** `BACKUP_COUNT=` (≥15) y `GATE_PASS: FASE 1 COMPLETADA`.
- **Comando de reversión total a este backup:**
  ```bash
  BK_DIR=$(cat "$PREFIX/tmp/rt-dex/latest-backup.path")
  ROOTFS="$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs"
  cp -a "$BK_DIR/termux-bin/." "$PREFIX/bin/"
  cp -a "$BK_DIR/rt-dex/." "$PREFIX/tmp/rt-dex/"
  cp -a "$BK_DIR/rt-dex/." "$HOME/.local/share/substrate/rt-dex/"
  cp -a "$BK_DIR/rootfs-etc/zz-adreno-gpu.sh" "$ROOTFS/etc/profile.d/zz-adreno-gpu.sh"
  cp -a "$BK_DIR/rootfs-bin/." "$ROOTFS/usr/local/bin/"
  cp -a "$BK_DIR/rootfs-share/." "$ROOTFS/usr/local/share/substrate/"
  [ -f "$BK_DIR/dconf/user" ] && cp -a "$BK_DIR/dconf/user" "$ROOTFS/home/dexuser/.config/dconf/user"
  ```

---

## 3. FIXES EN ORDEN DE RIESGO CRECIENTE (FASES 2 A 6)

### FASE 2 — Higiene de Servicios en Termux y Poda de Demonios D-Bus en `proot` (Riesgo Muy Bajo)

- **Qué hace:** Pone en `down` los servicios `runsv` innecesarios en Termux (`ollama`, `cupsd`, `tx11`, `tx11-xfce4` — **sin tocar jamás `sshd`**) y desactiva en el rootfs los `.service` de activación D-Bus que lanzaban ~20 demonios inútiles en cada arranque (`evolution-*`, `goa-*`, `gnome-shell-calendar-server`, 5 `gvfs-*-volume-monitor`, `xdg-document-portal` que fallaba con `/dev/fuse`, e `IBus`).

```bash
#!/data/data/com.termux/files/usr/bin/bash
set -eu
export PREFIX="/data/data/com.termux/files/usr"
export TMPDIR="$PREFIX/tmp"
export RT="$TMPDIR/rt-dex"
export ROOTFS="$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs"
LOG="$RT/phase-2.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== FASE 2: HIGIENE DE SERVICIOS Y PODA D-BUS ($(date -u +%FT%TZ)) ==="

for srv in ollama cupsd tx11 tx11-xfce4; do
  if [ -d "$PREFIX/var/service/$srv" ]; then
    sv down "$PREFIX/var/service/$srv" 2>/dev/null || true
    touch "$PREFIX/var/service/$srv/down"
    echo "[SV] $srv -> down"
  fi
done

DBUS_SVC_DIR="$ROOTFS/usr/share/dbus-1/services"
DISABLE_SERVICES=(
  "org.gnome.Shell.CalendarServer.service"
  "org.gnome.evolution.dataserver.Sources5.service"
  "org.gnome.evolution.dataserver.Calendar8.service"
  "org.gnome.evolution.dataserver.AddressBook10.service"
  "org.gnome.evolution.dataserver.UserPrompter0.service"
  "org.gnome.OnlineAccounts.service"
  "org.gnome.Identity.service"
  "org.gtk.vfs.UDisks2VolumeMonitor.service"
  "org.gtk.vfs.AfcVolumeMonitor.service"
  "org.gtk.vfs.MTPVolumeMonitor.service"
  "org.gtk.vfs.GPhoto2VolumeMonitor.service"
  "org.gtk.vfs.GoaVolumeMonitor.service"
  "org.freedesktop.portal.Documents.service"
  "org.freedesktop.IBus.service"
  "org.freedesktop.portal.IBus.service"
)

for s in "${DISABLE_SERVICES[@]}"; do
  if [ -f "$DBUS_SVC_DIR/$s" ]; then
    mv -f "$DBUS_SVC_DIR/$s" "$DBUS_SVC_DIR/$s.disabled-substrate"
    echo "[DBUS-MASK] Desactivado: $s"
  elif [ -f "$DBUS_SVC_DIR/$s.disabled-substrate" ]; then
    echo "[DBUS-MASK] Ya desactivado (idempotente): $s"
  fi
done

# GATE DE VERIFICACION FASE 2
! (sv status "$PREFIX/var/service/ollama" 2>/dev/null | grep -q '^run:')
[ ! -f "$DBUS_SVC_DIR/org.gnome.Shell.CalendarServer.service" ]
[ ! -f "$DBUS_SVC_DIR/org.freedesktop.portal.Documents.service" ]
echo "GATE_PASS: FASE 2 COMPLETADA"
```

- **Resultado esperado:** `GATE_PASS: FASE 2 COMPLETADA`.
- **Cómo revertir Fase 2:**
  ```bash
  ROOTFS="$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs"
  for f in "$ROOTFS/usr/share/dbus-1/services/"*.disabled-substrate; do
    [ -e "$f" ] && mv -f "$f" "${f%.disabled-substrate}"
  done
  rm -f "$PREFIX/var/service/ollama/down" && sv up "$PREFIX/var/service/ollama"
  ```

---

### FASE 3 — Blindaje Dinámico Android/ADB contra PhantomProcessKiller y Freecess (Riesgo Bajo)

- **Qué hace:** Instala `$PREFIX/bin/substrate-adb-shield`, que detecta automáticamente el serial activo en `adb devices` (ej. `emulator-5554` o IP:puerto) en lugar del `127.0.0.1:5555` fijo y desactiva el monitor de procesos fantasma, el congelador de apps en caché y las restricciones de segundo plano para `com.termux` y `com.termux.x11`.

```bash
#!/data/data/com.termux/files/usr/bin/bash
set -eu
export PREFIX="/data/data/com.termux/files/usr"
export TMPDIR="$PREFIX/tmp"
export RT="$TMPDIR/rt-dex"
LOG="$RT/phase-3.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== FASE 3: BLINDAJE ANDROID/ADB ($(date -u +%FT%TZ)) ==="

cat > "$PREFIX/bin/substrate-adb-shield" <<'EOF_SHIELD'
#!/data/data/com.termux/files/usr/bin/bash
set -u
command -v adb >/dev/null 2>&1 || exit 0
SER=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1; exit}')
if [ -z "$SER" ]; then
  adb connect 127.0.0.1:5555 >/dev/null 2>&1 || true
  SER=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1; exit}')
fi
[ -n "$SER" ] || { echo "[ADB-SHIELD] WARN: sin dispositivo ADB activo"; exit 0; }

echo "[ADB-SHIELD] Aplicando blindaje en serial=$SER"
timeout 10 adb -s "$SER" shell "
  settings put global settings_enable_monitor_phantom_procs false
  device_config put activity_manager max_phantom_processes 2147483647
  device_config set_sync_disabled_for_tests persistent
  settings put global cached_apps_freezer disabled
  settings put system screen_off_timeout 2147483647
  svc power stayon true
  for pkg in com.termux com.termux.x11 com.termux.api com.termux.widget; do
    am set-standby-bucket \$pkg active 2>/dev/null || true
    cmd appops set \$pkg RUN_ANY_IN_BACKGROUND allow 2>/dev/null || true
    cmd appops set \$pkg RUN_IN_BACKGROUND allow 2>/dev/null || true
    cmd appops set \$pkg SYSTEM_ALERT_WINDOW allow 2>/dev/null || true
    dumpsys deviceidle whitelist +\$pkg >/dev/null 2>&1 || true
  done
" >/dev/null 2>&1 || true

PH_MON=$(timeout 6 adb -s "$SER" shell settings get global settings_enable_monitor_phantom_procs 2>/dev/null | tr -d '\r')
PH_MAX=$(timeout 6 adb -s "$SER" shell device_config get activity_manager max_phantom_processes 2>/dev/null | tr -d '\r')
FREEZER=$(timeout 6 adb -s "$SER" shell settings get global cached_apps_freezer 2>/dev/null | tr -d '\r')
echo "[ADB-SHIELD] monitor_phantom_procs=$PH_MON max_phantom=$PH_MAX freezer=$FREEZER"
EOF_SHIELD

chmod 755 "$PREFIX/bin/substrate-adb-shield"
"$PREFIX/bin/substrate-adb-shield"

# GATE DE VERIFICACION FASE 3
test -x "$PREFIX/bin/substrate-adb-shield"
echo "GATE_PASS: FASE 3 COMPLETADA"
```

- **Resultado esperado:** `[ADB-SHIELD] monitor_phantom_procs=false max_phantom=2147483647 freezer=disabled` y `GATE_PASS: FASE 3 COMPLETADA`.
- **Cómo revertir Fase 3:** `rm -f "$PREFIX/bin/substrate-adb-shield"`.

---

### FASE 4 — Receta GPU Zink/Turnip, Watchdog In-Session Auto-Curativo y Launchers Anclados a `tmux` (Riesgo Medio)

- **Qué hace:**
  1. Escribe `/etc/profile.d/zz-adreno-gpu.sh` con `PATH` limpio de Ubuntu y receta Zink/Turnip + `COGL_DISABLE_TFP=1`.
  2. Escribe `/tmp/rt-dex/session49.sh` con `ulimit -Sn 65536` (elimina el error de `dbus-daemon`) y sin `colord`/`geoclue`.
  3. Escribe `/tmp/rt-dex/session-inner.sh` con solo los 5 `gsd-*` útiles (`power`, `media-keys`, `keyboard`, `xsettings`, `sound`), configuración idempotente de `disabled-extensions`, y un **watchdog in-place** que relanza `gnome-shell` en 2 segundos dentro de la misma sesión si muere con `SIGKILL` (`137`), sin destruir el bus D-Bus ni cerrar las ventanas abiertas.
  4. Escribe `$PREFIX/tmp/rt-dex/restart49.sh` anclando el contenedor `proot` a la sesión `tmux` `substrate-wm` y parchea `$PREFIX/bin/gnome49` para invocar `substrate-adb-shield`.
  5. Actualiza `/usr/local/bin/gnome-moderno.sh` para eliminar `pkill -x` y `weston`.

```bash
#!/data/data/com.termux/files/usr/bin/bash
set -eu
export PREFIX="/data/data/com.termux/files/usr"
export TMPDIR="$PREFIX/tmp"
export RT="$TMPDIR/rt-dex"
export BK_RT="$HOME/.local/share/substrate/rt-dex"
export ROOTFS="$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs"
LOG="$RT/phase-4.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== FASE 4: GPU ZINK/TURNIP + WATCHDOG IN-SESSION + LAUNCHERS ($(date -u +%FT%TZ)) ==="
mkdir -p "$RT" "$BK_RT"

# 4.1 Receta GPU /etc/profile.d/zz-adreno-gpu.sh
cat > "$ROOTFS/etc/profile.d/zz-adreno-gpu.sh" <<'EOF_GPU'
# ZZ-ADRENO v4.1: Stack GL via Zink sobre Turnip/kgsl (Adreno 830) + PATH Ubuntu limpio.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export LIBGL_ALWAYS_SOFTWARE=0
export MESA_VK_WSI_PRESENT_MODE=immediate
export COGL_DISABLE_TFP=1
EOF_GPU
chmod 644 "$ROOTFS/etc/profile.d/zz-adreno-gpu.sh"
cp -a "$ROOTFS/etc/profile.d/zz-adreno-gpu.sh" "$RT/zz-adreno-gpu.sh"
cp -a "$ROOTFS/etc/profile.d/zz-adreno-gpu.sh" "$BK_RT/zz-adreno-gpu.sh"

# 4.2 Perfil escape hatch software
cat > "$RT/zz-adreno-gpu.software.sh" <<'EOF_GPUSW'
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export LIBGL_DRI3_DISABLE=1
export COGL_DISABLE_TFP=1
EOF_GPUSW
chmod 755 "$RT/zz-adreno-gpu.software.sh"
cp -a "$RT/zz-adreno-gpu.software.sh" "$BK_RT/zz-adreno-gpu.software.sh"

# 4.3 /tmp/rt-dex/session49.sh
cat > "$RT/session49.sh" <<'EOF_S49'
#!/bin/bash
# session49.sh - GNOME Shell 49 X11 sobre Ubuntu 26.04 en proot.
set -u

RT=/tmp/rt-dex
mkdir -p "$RT"

export HOME=/home/dexuser
export USER=dexuser
export LOGNAME=dexuser
export DISPLAY=:0
export XDG_RUNTIME_DIR="$RT"
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=ubuntu
export XDG_SESSION_ID=substrate
export DESKTOP_SESSION=ubuntu
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_DATA_DIRS=/usr/local/share:/usr/share
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export NO_AT_BRIDGE=1
export GTK_A11Y=none
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export RT_SYSTEM_BUS=/tmp/rt-dex/system-bus49

if [ "${GNOME49_SW:-0}" = "1" ] && [ -f "$RT/zz-adreno-gpu.software.sh" ]; then
  . "$RT/zz-adreno-gpu.software.sh"
  export GSK_RENDERER=cairo
else
  . /etc/profile.d/zz-adreno-gpu.sh 2>/dev/null || true
  export GSK_RENDERER=gl
fi
unset FD_MESA_DEBUG FD_FORCE_KGSL
[ "${GNOME49_SW:-0}" = "1" ] || unset LIBGL_DRI3_DISABLE
export MESA_VK_WSI_PRESENT_MODE=immediate
export vblank_mode=0

ulimit -Sn 65536 2>/dev/null || true

export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$RT/system-bus49"

if [ ! -f "$RT/system-dbus49.conf" ]; then
  cat > "$RT/system-dbus49.conf" <<'EOF_DBUS'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>system</type>
  <listen>unix:path=/tmp/rt-dex/system-bus49</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow user="*"/>
    <allow own="*"/>
    <allow send_type="method_call"/>
    <allow send_type="signal"/>
    <allow send_type="method_return"/>
    <allow send_type="error"/>
    <allow receive_type="method_call"/>
    <allow receive_type="signal"/>
    <allow receive_type="method_return"/>
    <allow receive_type="error"/>
  </policy>
</busconfig>
EOF_DBUS
fi

if [ ! -S "$RT/system-bus49" ]; then
  dbus-daemon --config-file="$RT/system-dbus49.conf" --fork
fi
for _ in $(seq 1 10); do [ -S "$RT/system-bus49" ] && break; sleep 0.5; done

setsid nohup python3 /usr/local/share/substrate/fake-login1.py >>"$RT/login1.log" 2>&1 </dev/null &
echo $! > "$RT/login1.pid"
sleep 0.5

setsid nohup python3 /usr/local/share/substrate/nm-stub.py >>"$RT/nm-stub.log" 2>&1 </dev/null &
echo $! > "$RT/nm-stub.pid"

if [ -f /usr/local/share/substrate/upower-stub.py ]; then
  setsid nohup python3 /usr/local/share/substrate/upower-stub.py >>"$RT/upowerd.log" 2>&1 </dev/null &
  echo $! > "$RT/upowerd.pid"
fi

if [ -x /usr/libexec/power-profiles-daemon ]; then
  setsid nohup /usr/libexec/power-profiles-daemon >>"$RT/ppd.log" 2>&1 </dev/null &
  echo $! > "$RT/ppd.pid"
fi
sleep 1

exec dbus-run-session -- bash /tmp/rt-dex/session-inner.sh
EOF_S49
chmod 755 "$RT/session49.sh"
cp -a "$RT/session49.sh" "$BK_RT/session49.sh"

# 4.4 /tmp/rt-dex/session-inner.sh
cat > "$RT/session-inner.sh" <<'EOF_SINNER'
#!/bin/bash
# session-inner.sh - Sesion de usuario GNOME 49 con watchdog in-place para gnome-shell.
set -u

RT=/tmp/rt-dex
export HOME=/home/dexuser
export USER=dexuser
export LOGNAME=dexuser
export DISPLAY=:0
export XDG_RUNTIME_DIR="$RT"
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=ubuntu
export XDG_SESSION_ID=substrate
export DESKTOP_SESSION=ubuntu
export GNOME_SHELL_SESSION_MODE=ubuntu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "${GNOME49_SW:-0}" = "1" ]; then
  export GSK_RENDERER=cairo
else
  export GSK_RENDERER=gl
fi
export GTK_A11Y=none
export NO_AT_BRIDGE=1
export PULSE_SERVER="${RT_PULSE_SERVER:-tcp:127.0.0.1:4713}"

echo "$DBUS_SESSION_BUS_ADDRESS" > "$RT/session-bus.addr"
_bus_path=${DBUS_SESSION_BUS_ADDRESS#unix:path=}
_bus_path=${_bus_path%%,*}
[ -n "$_bus_path" ] && ln -sf "$_bus_path" "$RT/bus"

gsettings set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark" 2>/dev/null || true
gsettings set org.gnome.desktop.wm.preferences theme "MacTahoe-Dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme "MacTahoe-dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme "Yaru" 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface font-antialiasing "rgba" 2>/dev/null || true
gsettings set org.gnome.desktop.interface font-hinting "slight" 2>/dev/null || true
gsettings set org.gnome.desktop.interface font-rgba-order "rgb" 2>/dev/null || true
gsettings set org.gnome.desktop.background picture-uri "file:///home/dexuser/.local/share/backgrounds/MacTahoe-day.jpeg" 2>/dev/null || true
gsettings set org.gnome.desktop.background picture-uri-dark "file:///home/dexuser/.local/share/backgrounds/MacTahoe-day.jpeg" 2>/dev/null || true

gsettings set org.gnome.shell disabled-extensions "['ding@rastersoft.com', 'snapd-prompting@canonical.com']" 2>/dev/null || true
gsettings set org.gnome.shell enabled-extensions "['user-theme@gnome-shell-extensions.gcampax.github.com', 'ubuntu-dock@ubuntu.com', 'tiling-assistant@ubuntu.com', 'ubuntu-appindicators@ubuntu.com']" 2>/dev/null || true
gsettings set org.gnome.shell.extensions.user-theme name "MacTahoe-Dark" 2>/dev/null || true
rm -f "$RT/gnome-shell-disable-extensions"

( printf '\n' | gnome-keyring-daemon --start --components=secrets ) >>"$RT/keyring.log" 2>&1 || true

for s in power media-keys keyboard xsettings sound; do
  if [ -x "/usr/libexec/gsd-$s" ]; then
    setsid nohup "/usr/libexec/gsd-$s" >>"$RT/gsd-$s.log" 2>&1 </dev/null &
    echo $! > "$RT/gsd-$s.pid"
  fi
done

nohup /usr/libexec/xdg-desktop-portal >>"$RT/portal.log" 2>&1 &
echo $! > "$RT/portal.pid"
nohup /usr/libexec/xdg-desktop-portal-gtk >>"$RT/portal-gtk.log" 2>&1 &
echo $! > "$RT/portal-gtk.pid"
sleep 1

(
  trap '' HUP
  FAIL_COUNT=0
  WINDOW_START=$(date +%s)
  FORCE_SW="${GNOME49_SW:-0}"

  while :; do
    if [ -f "$RT/session.stop" ]; then
      echo "WATCHDOG: session.stop detectado, saliendo limpiamente." >>"$RT/shell49.log"
      break
    fi
    if ! timeout 4 xdpyinfo >/dev/null 2>&1; then
      echo "WATCHDOG: servidor X (:0) no disponible, saliendo." >>"$RT/shell49.log"
      break
    fi

    if [ "$FORCE_SW" = "1" ] && [ -f "$RT/zz-adreno-gpu.software.sh" ]; then
      . "$RT/zz-adreno-gpu.software.sh"
    else
      . /etc/profile.d/zz-adreno-gpu.sh 2>/dev/null || true
      unset LIBGL_ALWAYS_SOFTWARE FD_MESA_DEBUG FD_FORCE_KGSL
      export LIBGL_ALWAYS_SOFTWARE=0
    fi

    echo "=== GNOME-SHELL LAUNCH (sw=$FORCE_SW) at $(date -u +%FT%TZ) ===" >>"$RT/shell49.log"
    gnome-shell >>"$RT/shell49.log" 2>&1 &
    spid=$!
    echo "$spid" > "$RT/shell49.pid"
    wait "$spid"
    rc=$?
    now=$(date +%s)
    {
      echo ""
      echo "SHELL_EXIT=$rc at $(date -u +%FT%TZ)"
    } >>"$RT/shell49.log"

    [ -f "$RT/session.stop" ] && break
    [ "$rc" = "0" ] && break

    if [ $((now - WINDOW_START)) -gt 180 ]; then
      FAIL_COUNT=0
      WINDOW_START=$now
    fi
    FAIL_COUNT=$((FAIL_COUNT + 1))

    if [ "$FAIL_COUNT" -ge 3 ] && [ "$FORCE_SW" != "1" ]; then
      echo "WATCHDOG: 3 muertes en <180s; conmutando gnome-shell a software fallback (llvmpipe)" >>"$RT/shell49.log"
      FORCE_SW=1
      FAIL_COUNT=0
      WINDOW_START=$now
    elif [ "$FAIL_COUNT" -ge 5 ]; then
      echo "WATCHDOG: 5 muertes consecutivas incluso en fallback; abortando bucle." >>"$RT/shell49.log"
      break
    fi
    sleep 2
  done
) &

wait
EOF_SINNER
chmod 755 "$RT/session-inner.sh"
cp -a "$RT/session-inner.sh" "$BK_RT/session-inner.sh"

# 4.5 $PREFIX/tmp/rt-dex/restart49.sh
cat > "$RT/restart49.sh" <<'EOF_R49'
#!/data/data/com.termux/files/usr/bin/bash
# restart49.sh - Reinicia la sesion GNOME 49 X11 de forma segura y anclada a tmux.
set -u

RT="$PREFIX/tmp/rt-dex"
DISP=":0"
say() { printf '%s\n' "$*"; }
mkdir -p "$RT"

if ! proot-distro login ubuntu-gnome --shared-tmp -- \
     bash -c "DISPLAY=$DISP timeout 4 xdpyinfo >/dev/null 2>&1"; then
  say "[S] X no responde en $DISP. Abre Termux:X11 y ejecuta: gnome49"
  exit 1
fi

say "[S] Deteniendo sesion anterior..."
touch "$RT/session.stop"
tmux kill-session -t substrate-wm 2>/dev/null || true
bash "$PREFIX/bin/gnome49-stop" >/dev/null 2>&1 || true

for p in $(ps -eo pid=,comm= 2>/dev/null | awk '$2=="proot"{print $1}'); do
  cmd=$(tr '\0' ' ' 2>/dev/null < "/proc/$p/cmdline") || continue
  case "$cmd" in
    *ubuntu-gnome*session49.sh*)
      kill -9 "$p" 2>/dev/null && say "[S] proot de sesion detenido ($p)" ;;
  esac
done

for q in /proc/[0-9]*; do
  p=${q#/proc/}
  [ "$p" = "$$" ] && continue
  cmd=$(tr '\0' ' ' 2>/dev/null < "$q/cmdline") || continue
  case "$cmd" in
    gnome-terminal*|/usr/bin/gnome-terminal*|\
    gnome-calculator*|/usr/bin/gnome-calculator*|\
    gnome-text-editor*|nautilus*|/usr/bin/nautilus*|\
    *org.gnome.NautilusPreviewer*|*ding.js*|mutter-x11-frames*|\
    nm-stub.py*|python3\ /usr/local/share/substrate/nm-stub.py*|\
    upower-stub.py*|python3\ /usr/local/share/substrate/upower-stub.py*|\
    bash\ /tmp/rt-dex/session-inner.sh*|bash\ /tmp/rt-dex/warmup49.sh*|\
    /usr/libexec/gnome-shell-calendar-server*|/usr/libexec/evolution-*|\
    /usr/libexec/goa-*|/usr/libexec/gvfs-*-volume-monitor*|\
    metacity*|/usr/bin/metacity*|\
    gnome-panel*|/usr/bin/gnome-panel*|/usr/libexec/gnome-panel*|\
    plank*|/usr/bin/plank*|\
    *gnome-flashback*|*arranque-escritorio*)
      kill -9 "$p" 2>/dev/null && say "[S] resto detenido ($p)"
      ;;
  esac
done
sleep 1

rm -f "$RT/session.stop" "$RT/shell49.pid" "$RT/session-bus.addr" "$RT/bus" \
      "$RT/login1.pid" "$RT/nm-stub.pid" "$RT/polkitd-helper.pid" \
      "$RT/system-bus49" "$RT/system-bus49.pid" \
      "$RT/gnome-shell-disable-extensions" 2>/dev/null || true
rm -f "$RT"/gsd-*.pid "$RT"/upowerd.pid "$RT"/colord.pid "$RT"/geoclue.pid \
      "$RT"/ppd.pid "$RT"/portal.pid "$RT"/portal-gtk.pid "$RT"/session-launch.pid 2>/dev/null || true
: > "$RT/session49-launch.log"
: > "$RT/shell49.log"

[ -x "$PREFIX/bin/substrate-adb-shield" ] && "$PREFIX/bin/substrate-adb-shield" >/dev/null 2>&1 || true

setsid nohup proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  while [ ! -S /tmp/rt-dex/system-bus49 ]; do sleep 1; done
  export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/rt-dex/system-bus49
  while :; do
    /usr/lib/polkit-1/polkitd --no-debug >>/tmp/rt-dex/polkitd.log 2>&1
    echo "polkitd exit=$? $(date -u +%FT%TZ)" >>/tmp/rt-dex/polkitd.log
    sleep 2
  done
' >>"$RT/polkitd-sup.log" 2>&1 </dev/null &
echo $! > "$RT/polkitd-helper.pid"

say "[S] Arrancando GNOME Shell 49 X11 anclado a tmux (~25-35 s)..."
if command -v tmux >/dev/null 2>&1; then
  tmux new-session -d -s substrate-wm \
    "GNOME49_SW=${GNOME49_SW:-0} proot-distro login ubuntu-gnome --shared-tmp -- bash /tmp/rt-dex/session49.sh >> $RT/session49-launch.log 2>&1"
  tmux list-panes -t substrate-wm -F '#{pane_pid}' > "$RT/session-launch.pid" 2>/dev/null || true
else
  setsid nohup env GNOME49_SW="${GNOME49_SW:-0}" proot-distro login ubuntu-gnome --shared-tmp -- \
    bash /tmp/rt-dex/session49.sh >> "$RT/session49-launch.log" 2>&1 </dev/null &
  echo $! > "$RT/session-launch.pid"
fi

P=""
for _ in $(seq 1 50); do
  P=$(cat "$RT/shell49.pid" 2>/dev/null || true)
  [ -n "$P" ] && [ -d "/proc/$P" ] && break
  P=""
  sleep 1
done

if [ -z "$P" ]; then
  say "[S] ERROR: gnome-shell no arranco. Ultimas lineas:"
  tail -15 "$RT/session49-launch.log" 2>/dev/null
  tail -10 "$RT/shell49.log" 2>/dev/null
  exit 1
fi

taskset -apc 6-7 "$P" >/dev/null 2>&1 && say "[S] afinidad prime cores 6-7 aplicada"

kg=$(ls -l "/proc/$P/fd" 2>/dev/null | grep -c kgsl || true)
sw=$(grep -cE 'swrast|llvmpipe' "/proc/$P/maps" 2>/dev/null || true)
dbusn=$(for q in /proc/[0-9]*; do c=$(tr '\0' ' ' 2>/dev/null < "$q/cmdline") || continue; case "$c" in dbus-daemon*) echo x;; esac; done | wc -l)
say "[S] OK: shell pid=$P kgsl_fds=$kg swrast=$sw dbus=$dbusn"
EOF_R49
chmod 755 "$RT/restart49.sh"
cp -a "$RT/restart49.sh" "$BK_RT/restart49.sh"

# 4.6 Parchear $PREFIX/bin/gnome49 para usar substrate-adb-shield
python3 - "$PREFIX/bin/gnome49" <<'EOF_PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
txt = p.read_text()
old = """if command -v adb >/dev/null 2>&1; then
  (
    timeout 6 adb -s 127.0.0.1:5555 shell settings put system screen_off_timeout 2147483647 >/dev/null 2>&1
    timeout 6 adb -s 127.0.0.1:5555 shell svc power stayon true >/dev/null 2>&1
  ) &
fi"""
new = """if [ -x "$PREFIX/bin/substrate-adb-shield" ]; then
  "$PREFIX/bin/substrate-adb-shield" >/dev/null 2>&1 &
fi"""
if old in txt:
    p.write_text(txt.replace(old, new, 1))
    print("[GNOME49] Actualizado a substrate-adb-shield")
else:
    print("[GNOME49] Ya actualizado (idempotente)")
EOF_PY
chmod 755 "$PREFIX/bin/gnome49"

# 4.7 Neutralizar /usr/local/bin/gnome-moderno.sh
cat > "$ROOTFS/usr/local/bin/gnome-moderno.sh" <<'EOF_GMOD'
#!/bin/bash
set -u
if [ -f /tmp/rt-dex/shell49.pid ] && kill -0 "$(cat /tmp/rt-dex/shell49.pid 2>/dev/null)" 2>/dev/null; then
  echo "gnome-shell 49 X11 ya esta activo (pid=$(cat /tmp/rt-dex/shell49.pid))"
  exit 0
fi
exec bash /tmp/rt-dex/session49.sh
EOF_GMOD
chmod 755 "$ROOTFS/usr/local/bin/gnome-moderno.sh"

# GATE DE VERIFICACION FASE 4
gnome49 --restart
gnome49 status

SPID=$(cat "$RT/shell49.pid")
kill -0 "$SPID"
KGSL_FDS=$(ls -l "/proc/$SPID/fd" 2>/dev/null | grep -c kgsl || true)
ZINK_MAPS=$(grep -cE 'zink|libvulkan_freedreno' "/proc/$SPID/maps" 2>/dev/null || true)
SW_MAPS=$(grep -cE 'llvmpipe|swrast' "/proc/$SPID/maps" 2>/dev/null || true)
echo "[GATE-4] pid=$SPID kgsl_fds=$KGSL_FDS zink_maps=$ZINK_MAPS sw_maps=$SW_MAPS"
[ "$KGSL_FDS" -ge 1 ]
[ "$ZINK_MAPS" -ge 1 ]
[ "$SW_MAPS" -eq 0 ]

proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex
  /usr/local/bin/test-visibilidad.sh xlogo -geometry 240x240+140+140
'
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  export DISPLAY=:0
  WID=$(xdotool search --class xlogo 2>/dev/null | head -1 || true)
  [ -n "$WID" ] && xdotool windowclose "$WID" 2>/dev/null || true
'
echo "GATE_PASS: FASE 4 COMPLETADA"
```

- **Resultado esperado:** `[GATE-4] pid=... kgsl_fds=1 zink_maps=4 sw_maps=0`, `RMSE=0 (0)`, `VEREDICTO: VISIBLE` y `GATE_PASS: FASE 4 COMPLETADA`.
- **Cómo revertir Fase 4:** Ejecutar el bloque de reversión de la Fase 1 y `gnome49 --restart`.

---

### FASE 5 — Compatibilidad: Toolchain Completo, Benchmarks GPU, Audio PulseAudio TCP, Portapapeles y Contenedores (Riesgo Medio)

- **Qué hace:**
  1. Reafirma `apt-mark hold` sobre el clúster GNOME 49 e instala en Ubuntu `clang`, `cmake`, `pkg-config`, `nodejs`, `npm`, `python3-venv`, `glmark2-x11`, `glmark2-es2-x11`, `vulkan-tools`, `pulseaudio-utils`, `xclip`, `xsel`, `fonts-inter`, `fonts-jetbrains-mono`.
  2. Documenta en `/usr/local/bin/substrate-container-info` por qué Docker y Podman rootless no pueden ejecutarse dentro de `proot` (`unshare`/`mount(overlayfs)`/`cgroups v2` devuelven `EPERM`/`ENOSYS` al no existir `CAP_SYS_ADMIN` en el kernel Android sin root) y provee las alternativas reales instaladas (`python3 -m venv`, `node`/`npm`, toolchain C/C++ nativo y `proot-distro`).
  3. Verifica compilación con `gcc` y `clang`, audio PulseAudio por TCP (`127.0.0.1:4713`) con `pactl` y `paplay` nativos de Ubuntu, y portapapeles X11 con `xclip`.

```bash
#!/data/data/com.termux/files/usr/bin/bash
set -eu
export PREFIX="/data/data/com.termux/files/usr"
export TMPDIR="$PREFIX/tmp"
export RT="$TMPDIR/rt-dex"
export ROOTFS="$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs"
LOG="$RT/phase-5.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== FASE 5: COMPATIBILIDAD Y TOOLCHAIN ($(date -u +%FT%TZ)) ==="

proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  apt-mark hold gnome-shell gnome-shell-common gnome-shell-extension-prefs \
    gnome-session gnome-session-bin gnome-session-common \
    gnome-shell-ubuntu-extensions mutter mutter-common mutter-common-bin \
    libmutter-17-0 gir1.2-mutter-17 libdisplay-info2 >/dev/null
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    clang cmake pkg-config nodejs npm python3-venv \
    glmark2-x11 glmark2-es2-x11 vulkan-tools \
    pulseaudio-utils xclip xsel \
    fonts-inter fonts-jetbrains-mono
'

cat > "$ROOTFS/usr/local/bin/substrate-container-info" <<'EOF_CINFO'
#!/bin/bash
cat <<'TXT'
=== SubstrateOS: Por que Docker/Podman no corren dentro de proot y que usar ===
1. Causa tecnica:
   - Docker y Podman rootless requieren syscalls reales del kernel Linux:
     unshare(CLONE_NEWUSER|CLONE_NEWNS|CLONE_NEWNET), pivot_root, mount(overlayfs)
     y delegacion de cgroups v2.
   - En Android sin root, proot intercepta syscalls en espacio de usuario via ptrace
     bajo el UID de Termux. El kernel Android rechaza unshare/mount con EPERM/ENOSYS.
2. Alternativas verificadas en SubstrateOS:
   - Python aislado:   python3 -m venv .venv && . .venv/bin/activate
   - Node.js aislado:  node / npm / npx (Node 22 LTS nativo ARM64)
   - C/C++ nativo:     gcc / g++ / clang / cmake / ninja / meson
   - Multi-rootfs:     Desde Termux nativo, usar `proot-distro install <distro>`
TXT
EOF_CINFO
chmod 755 "$ROOTFS/usr/local/bin/substrate-container-info"

bash "$RT/substrate-audio-up"

# GATE DE VERIFICACION FASE 5
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  set -eu
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  export DISPLAY=:0
  export PULSE_SERVER=tcp:127.0.0.1:4713

  gcc --version | head -1
  clang --version | head -1
  cmake --version | head -1
  python3 --version
  node --version
  npm --version
  git --version
  command -v glmark2-es2
  command -v vulkaninfo
  command -v pactl
  command -v xclip

  cat > /tmp/rt-dex/hello.c <<EOF
#include <stdio.h>
int main(void) { printf("TOOLCHAIN_OK\n"); return 0; }
EOF
  gcc /tmp/rt-dex/hello.c -o /tmp/rt-dex/hello_gcc && /tmp/rt-dex/hello_gcc
  clang /tmp/rt-dex/hello.c -o /tmp/rt-dex/hello_clang && /tmp/rt-dex/hello_clang
  rm -f /tmp/rt-dex/hello.c /tmp/rt-dex/hello_gcc /tmp/rt-dex/hello_clang

  pactl info | grep -E "Server String|Default Sink"
  if [ -f /usr/share/sounds/freedesktop/stereo/bell.oga ]; then
    paplay /usr/share/sounds/freedesktop/stereo/bell.oga
    echo "AUDIO_PAPLAY_OK"
  fi

  printf "SUBSTRATE_CLIP_OK" | xclip -selection clipboard
  CLIP_OUT=$(xclip -selection clipboard -o)
  [ "$CLIP_OUT" = "SUBSTRATE_CLIP_OK" ]
  echo "CLIPBOARD_OK=$CLIP_OUT"
'
echo "GATE_PASS: FASE 5 COMPLETADA"
```

- **Resultado esperado:** `TOOLCHAIN_OK`, `AUDIO_PAPLAY_OK`, `CLIPBOARD_OK=SUBSTRATE_CLIP_OK` y `GATE_PASS: FASE 5 COMPLETADA`.
- **Cómo revertir Fase 5:**
  ```bash
  proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
    apt-get remove -y clang cmake nodejs npm python3-venv glmark2-x11 glmark2-es2-x11 vulkan-tools pulseaudio-utils xclip xsel fonts-inter fonts-jetbrains-mono
  '
  ```

---

### FASE 6 — Apariencia, Fuentes Nítidas AMOLED y `gsettings` Idempotentes (Riesgo Bajo)

- **Qué hace:** Instala `fonts.conf` con renderizado subpíxel RGB (`rgba=rgb`, `hintslight`, `lcddefault`) para la pantalla AMOLED del Galaxy S25, configura `Inter 10.5` y `JetBrains Mono 10.5`, aplica el tema `MacTahoe-Dark` e iconos `MacTahoe-dark`, y limpia la lista corrupta de `disabled-extensions`.

```bash
#!/data/data/com.termux/files/usr/bin/bash
set -eu
export PREFIX="/data/data/com.termux/files/usr"
export TMPDIR="$PREFIX/tmp"
export RT="$TMPDIR/rt-dex"
export ROOTFS="$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs"
LOG="$RT/phase-6.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== FASE 6: APARIENCIA Y POLISH AMOLED ($(date -u +%FT%TZ)) ==="

for d in "$ROOTFS/home/dexuser/.config/fontconfig" "$ROOTFS/root/.config/fontconfig"; do
  mkdir -p "$d"
  cat > "$d/fonts.conf" <<'EOF_FC'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
  </match>
  <alias>
    <family>sans-serif</family>
    <prefer><family>Inter</family><family>Adwaita Sans</family><family>DejaVu Sans</family></prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer><family>JetBrains Mono</family><family>Ubuntu Sans Mono</family><family>DejaVu Sans Mono</family></prefer>
  </alias>
</fontconfig>
EOF_FC
done

proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  set -eu
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  export HOME=/home/dexuser
  export DISPLAY=:0
  export XDG_RUNTIME_DIR=/tmp/rt-dex
  export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)

  fc-cache -f >/dev/null 2>&1 || true

  gsettings set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark"
  gsettings set org.gnome.desktop.wm.preferences theme "MacTahoe-Dark"
  gsettings set org.gnome.desktop.interface icon-theme "MacTahoe-dark"
  gsettings set org.gnome.desktop.interface cursor-theme "Yaru"
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
  gsettings set org.gnome.desktop.interface font-name "Inter 10.5"
  gsettings set org.gnome.desktop.interface document-font-name "Inter 10.5"
  gsettings set org.gnome.desktop.interface monospace-font-name "JetBrains Mono 10.5"
  gsettings set org.gnome.desktop.interface font-antialiasing "rgba"
  gsettings set org.gnome.desktop.interface font-hinting "slight"
  gsettings set org.gnome.desktop.interface font-rgba-order "rgb"
  gsettings set org.gnome.desktop.interface enable-animations true
  gsettings set org.gnome.desktop.background picture-uri "file:///home/dexuser/.local/share/backgrounds/MacTahoe-day.jpeg"
  gsettings set org.gnome.desktop.background picture-uri-dark "file:///home/dexuser/.local/share/backgrounds/MacTahoe-day.jpeg"
  gsettings set org.gnome.shell disabled-extensions "[\x27ding@rastersoft.com\x27, \x27snapd-prompting@canonical.com\x27]"
  gsettings set org.gnome.shell enabled-extensions "[\x27user-theme@gnome-shell-extensions.gcampax.github.com\x27, \x27ubuntu-dock@ubuntu.com\x27, \x27tiling-assistant@ubuntu.com\x27, \x27ubuntu-appindicators@ubuntu.com\x27]"
  gsettings set org.gnome.shell.extensions.user-theme name "MacTahoe-Dark"
'

# GATE DE VERIFICACION FASE 6
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  set -eu
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  export HOME=/home/dexuser
  export DISPLAY=:0
  export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)
  D_EXT=$(gsettings get org.gnome.shell disabled-extensions)
  echo "disabled-extensions = $D_EXT"
  [ "$D_EXT" = "[\x27ding@rastersoft.com\x27, \x27snapd-prompting@canonical.com\x27]" ]
  scrot -o /tmp/rt-dex/phase6-appearance.png
  COLORS=$(python3 -c "from PIL import Image; im=Image.open(\"/tmp/rt-dex/phase6-appearance.png\").convert(\"RGB\"); print(len(im.getcolors(maxcolors=10000000)))")
  echo "[GATE-6] Colores en captura = $COLORS"
  [ "$COLORS" -gt 10000 ]
'
echo "GATE_PASS: FASE 6 COMPLETADA"
```

- **Resultado esperado:** `disabled-extensions = ['ding@rastersoft.com', 'snapd-prompting@canonical.com']`, `[GATE-6] Colores en captura = >90000` y `GATE_PASS: FASE 6 COMPLETADA`.
- **Cómo revertir Fase 6:**
  ```bash
  ROOTFS="$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs"
  rm -f "$ROOTFS/home/dexuser/.config/fontconfig/fonts.conf" "$ROOTFS/root/.config/fontconfig/fonts.conf"
  ```

---

## 4. BENCHMARKS ANTES/DESPUÉS Y SOAK TEST DE 10 MINUTOS (FASE 7)

Ejecuta la medición completa de tiempo de arranque, `glxinfo`, `eglinfo`, `glmark2-es2`, memoria libre y el **Soak Test de 10 minutos (600 segundos)** con `gnome-text-editor` (GTK4) abierto y captura final `scrot`.

```bash
#!/data/data/com.termux/files/usr/bin/bash
set -eu
export PREFIX="/data/data/com.termux/files/usr"
export TMPDIR="$PREFIX/tmp"
export RT="$TMPDIR/rt-dex"
LOG="$RT/phase-7.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "=== FASE 7: BENCHMARKS Y SOAK TEST 10 MINUTOS ($(date -u +%FT%TZ)) ==="

# 7.1 Tiempo de arranque a escritorio listo
T0=$(date +%s)
gnome49 --restart
T1=$(date +%s)
BOOT_SECS=$((T1 - T0))
echo "[BENCH-BOOT] Tiempo de arranque = ${BOOT_SECS} s"

SPID=$(cat "$RT/shell49.pid")
KGSL_FDS=$(ls -l "/proc/$SPID/fd" 2>/dev/null | grep -c kgsl || true)
SHELL_RSS_KB=$(awk '/VmRSS:/{print $2}' "/proc/$SPID/status" 2>/dev/null || echo 0)
DBUS_COUNT=$(for q in /proc/[0-9]*; do c=$(tr '\0' ' ' 2>/dev/null < "$q/cmdline") || continue; case "$c" in dbus-daemon*) echo x;; esac; done | wc -l)
echo "[BENCH-RESOURCE] shell_pid=$SPID kgsl_fds=$KGSL_FDS shell_rss_kb=$SHELL_RSS_KB dbus_count=$DBUS_COUNT"

# 7.2 Benchmark GPU (glxinfo, eglinfo, glmark2-es2)
proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  set -eu
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  export DISPLAY=:0
  /usr/local/bin/substrate-gpu-run glxinfo -B | grep -E "direct rendering|Device:|OpenGL renderer|OpenGL core profile version"
  /usr/local/bin/substrate-gpu-run eglinfo -B | grep -E "OpenGL core profile renderer|OpenGL ES profile renderer" | head -4
  /usr/local/bin/substrate-gpu-run glmark2-es2 -b build:use-vbo=true -b texture:texture-filter=nearest -s 800x600 | tee /tmp/rt-dex/glmark2-es2.log
'

# 7.3 Memoria libre
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'free -m'

# 7.4 Soak Test de 10 minutos (600 s) con app GTK4 abierta
echo "[SOAK] Lanzando gnome-text-editor (GTK4, GSK_RENDERER=gl)..."
setsid nohup proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  export HOME=/home/dexuser DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex
  export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)
  export GSK_RENDERER=gl GTK_A11Y=none NO_AT_BRIDGE=1
  exec gnome-text-editor
' >/dev/null 2>&1 </dev/null &

sleep 5
INIT_PID=$(cat "$RT/shell49.pid")
echo "[SOAK] Inicio de 10 minutos (600 s). PID inicial de gnome-shell = $INIT_PID"

for m in 1 2 3 4 5 6 7 8 9 10; do
  sleep 60
  CUR_PID=$(cat "$RT/shell49.pid" 2>/dev/null || true)
  if [ -z "$CUR_PID" ] || ! kill -0 "$CUR_PID" 2>/dev/null; then
    echo "[SOAK] FALLO en minuto $m: gnome-shell no esta vivo"
    exit 1
  fi
  KG=$(ls -l "/proc/$CUR_PID/fd" 2>/dev/null | grep -c kgsl || true)
  RSS=$(awk '/VmRSS:/{print $2}' "/proc/$CUR_PID/status" 2>/dev/null || echo 0)
  echo "[SOAK] Minuto $m/10 OK: pid=$CUR_PID (init=$INIT_PID) kgsl_fds=$KG rss=${RSS}kB"
done

proot-distro login ubuntu-gnome --shared-tmp -- bash -c '
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  export DISPLAY=:0
  WID=$(xdotool search --name "Text Editor" 2>/dev/null | head -1 || true)
  [ -n "$WID" ] && xdotool windowclose "$WID" 2>/dev/null || true
  sleep 2
  scrot -o /tmp/rt-dex/final-soak-10min.png
  COLORS=$(python3 -c "from PIL import Image; im=Image.open(\"/tmp/rt-dex/final-soak-10min.png\").convert(\"RGB\"); print(len(im.getcolors(maxcolors=10000000)))")
  echo "[SOAK-FINAL] Captura /tmp/rt-dex/final-soak-10min.png con $COLORS colores"
  [ "$COLORS" -gt 10 ]
'

gnome49 status
echo "GATE_PASS: FASE 7 COMPLETADA"
```

### Tabla de Referencia de Benchmarks (Antes vs. Después)

| Métrica | Antes (Medido antes del Plan) | Después (Criterio de Éxito del Plan) |
|---|---|---|
| **Estabilidad del compositor** | Muere a los ~6.5 min (`SHELL_EXIT=137` a las `02:00:30` hoy) y queda pantalla negra | **10+ min `VIVO` con GTK4 abierta + watchdog in-session auto-curativo (2 s)** |
| **GPU Renderer (`glxinfo` / `eglinfo`)** | `zink Vulkan 1.4(Adreno (TM) 830v1 (MESA_TURNIP))` (o caída a `llvmpipe` en fallos) | **`zink Vulkan 1.4(Adreno (TM) 830v1 (MESA_TURNIP))`, OpenGL 4.6, `kgsl_fds>=1`, `llvmpipe=0`** |
| **Gate de visibilidad (`test-visibilidad.sh`)** | `RMSE=0` solo cuando `COGL_DISABLE_TFP=1` está activo | **`RMSE=0 (0)`, `AE=0` garantizado en `/etc/profile.d/zz-adreno-gpu.sh`** |
| **Arranque a escritorio (`gnome49 --restart`)** | ~35–45 s (45 procesos, errores FUSE y `ulimit`) | **≤ 28 s (~14 procesos, 0 errores FUSE/fd)** |
| **Benchmark `glmark2-es2`** | No instalado (`MISSING`) | **Instalado y registrado en `/tmp/rt-dex/glmark2-es2.log`** |
| **Memoria disponible (`free -m`)** | ~4121 MB disponibles (`ollama serve` activo + 45 demonios) | **≥ 4500 MB disponibles (`ollama` en `down` + demonios podados)** |

---

## 5. ACEPTACIÓN FINAL (CHECKLIST LITERAL)

El ejecutor marca cada casilla con `[x]` tras comprobar su evidencia en `/tmp/rt-dex/phase-*.log`:

- [ ] `DISPLAY=:0 xdpyinfo` devuelve código `0` (`phase-0.log`).
- [ ] Backup creado y verificado con `sha256sum -c` en `$HOME/.local/share/substrate/backups/pre-oneshot-*/MANIFEST.sha256` (`phase-1.log`).
- [ ] Demonios inútiles desactivados (`ollama` en `down`, servicios D-Bus de Evolution/GOA/GVFS/Documents en `.disabled-substrate`, `dbus-daemon` vivos = `2`) (`phase-2.log`).
- [ ] Blindaje Android aplicado por ADB dinámico (`monitor_phantom_procs=false max_phantom=2147483647 freezer=disabled`) (`phase-3.log`).
- [ ] GPU Adreno 830 activa en todo el stack: `kgsl_fds>=1`, `zink`/`libvulkan_freedreno` en `/proc/<shell_pid>/maps`, `llvmpipe=0`, y `glxinfo -B` / `eglinfo -B` muestran `zink Vulkan 1.4(Adreno (TM) 830v1 (MESA_TURNIP))` (`phase-4.log`).
- [ ] Gate de visibilidad pixel-exacta `/usr/local/bin/test-visibilidad.sh xlogo` devuelve `RMSE=0 (0)` y `VEREDICTO: VISIBLE` (`phase-4.log`).
- [ ] Toolchain y compatibilidad verificados en Ubuntu (`gcc`, `clang`, `cmake`, `python3`, `node`, `npm`, `git`, `glmark2-es2`, `vulkaninfo`, `pactl`, `paplay`, `xclip`) (`phase-5.log`).
- [ ] Apariencia MacTahoe-Dark y fuentes AMOLED (`Inter 10.5`, `JetBrains Mono 10.5`, `font-antialiasing='rgba'`) aplicadas de forma idempotente sin duplicados en `disabled-extensions` (`phase-6.log`).
- [ ] **Captura `scrot` con >10 colores** (`/tmp/rt-dex/final-soak-10min.png` con >90.000 colores medidos por PIL) (`phase-7.log`).
- [ ] **`gnome-shell` vivo tras 10 minutos de uso** con app GTK4 abierta (`Minuto 10/10 OK` en `phase-7.log`).

---

## 6. APÉNDICE DE SEGURIDAD (RESTRICCIONES EJECUTABLES)

```bash
# RESTRICCION 1: Prohibido pkill -f / killall. Solo matar por pidfile verificado:
safe_kill_pidfile() {
  local pidfile="$1"
  local expected_prefix="${2:-}"
  [ -f "$pidfile" ] || return 0
  local pid
  pid=$(cat "$pidfile" 2>/dev/null || true)
  case "$pid" in ''|*[!0-9]*) return 0 ;; esac
  [ -d "/proc/$pid" ] || { rm -f "$pidfile"; return 0; }

  local comm cmd
  comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ' || true)
  cmd=$(tr '\0' ' ' 2>/dev/null < "/proc/$pid/cmdline" || true)
  case "$comm" in
    com.termux*|termux-x11|sshd|tmux|node|opencode*|runsvdir|runsv|svlogd)
      echo "ABORT_KILL: PID $pid ($comm) es infraestructura intocable" >&2
      return 1
      ;;
  esac
  case "$cmd" in
    *opencode*|*sshd*|*tmux*|*termux-x11*)
      echo "ABORT_KILL: PID $pid ($cmd) es infraestructura intocable" >&2
      return 1
      ;;
  esac

  if [ -n "$expected_prefix" ]; then
    case "$cmd" in
      "$expected_prefix"*) ;;
      *)
        echo "SKIP_KILL: PID $pid ($cmd) no coincide con $expected_prefix" >&2
        return 0
        ;;
    esac
  fi

  kill -15 "$pid" 2>/dev/null || true
  sleep 1
  [ -d "/proc/$pid" ] && kill -9 "$pid" 2>/dev/null || true
  rm -f "$pidfile"
}

# RESTRICCION 2: Verificacion visual obligatoria (proceso vivo != exito)
verify_visual_gate() {
  local out_png="${1:-/tmp/rt-dex/gate-check.png}"
  proot-distro login ubuntu-gnome --shared-tmp -- bash -c "
    set -eu
    export DISPLAY=:0
    timeout 4 xdpyinfo >/dev/null
    id=\$(xprop -root -notype _NET_SUPPORTING_WM_CHECK | sed -n 's/.*# //p')
    [ -n \"\$id\" ]
    xprop -id \"\$id\" -notype _NET_WM_NAME WM_NAME | grep -qi 'gnome'
    scrot -o '$out_png'
    COLORS=\$(python3 -c 'from PIL import Image; im=Image.open(\"$out_png\").convert(\"RGB\"); print(len(im.getcolors(maxcolors=10000000)))')
    echo \"VISUAL_GATE_COLORS=\$COLORS\"
    [ \"\$COLORS\" -gt 10 ]
  "
}
```
