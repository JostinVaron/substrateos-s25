# Operación, pruebas y recuperación

## 1. Comandos de todos los días

```bash
gnome49              # arranca o mantiene la sesión
gnome49 status       # estado real (X, shell, WM, ventanas)
gnome49 --restart    # reinicio completo sin tocar X
gnome49-stop         # parada segura de la sesión
```

Nunca usar:

```bash
pkill -f gnome-shell     # PROHIBIDO
pkill -f proot           # PROHIBIDO
pkill -f termux          # PROHIBIDO
```

proot comparte `/proc`; esos patrones pueden matar SSH/tmux/OpenCode/Termux.

---

## 2. Comprobación de estado

```bash
gnome49 status
```

Salida esperada en el modo estable actual:

```
[X] Servidor :0 OK
[S] Sesion activa: gnome-shell pid=...
[W] WM: GNOME Shell OK
    kgsl_fds=0
[V] Ventanas visibles:
```

`kgsl_fds=0` **no es un error** en el modo software. Significa que el compositor no está usando kgsl; las apps GPU lo usan por separado.

Comprobación X:

```bash
proot-distro login ubuntu-gnome --shared-tmp -- bash -lc \
  'DISPLAY=:0 xdpyinfo | head -20'
```

Comprobación de captura/color:

```bash
proot-distro login ubuntu-gnome --shared-tmp -- bash -lc '
  DISPLAY=:0 scrot -o /tmp/rt-dex/check.png
  python3 -c "from PIL import Image; im=Image.open(\"/tmp/rt-dex/check.png\").convert(\"RGB\"); print(len(im.getcolors(maxcolors=10000000)))"
'
```

Criterio: **>90.000 colores** (compositor Zink). Últimas mediciones: 93.315 / 94.137 / 94.847.

---

## 3. Abrir y cerrar apps

### Text Editor (GTK4)

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc '
  export HOME=/home/dexuser DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex
  export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)
  export GSK_RENDERER=gl GTK_A11Y=none NO_AT_BRIDGE=1
  exec gnome-text-editor
'
```

Comprobar ventana:

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc '
  DISPLAY=:0 xwininfo -root -tree | grep -E "Text Editor|New Document"
'
```

Cerrar:

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc '
  DISPLAY=:0 xdotool search --name "Text Editor" windowclose
'
```

Después:

```bash
gnome49 status
```

### Calculator (GTK4)

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc '
  export HOME=/home/dexuser DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex
  export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)
  export GSK_RENDERER=gl GTK_A11Y=none NO_AT_BRIDGE=1
  exec gnome-calculator
'
```

Cerrar:

```bash
DISPLAY=:0 xdotool search --name "Calculator" windowclose
```

### Widget Factory

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc '
  export HOME=/home/dexuser DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex
  export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)
  export GSK_RENDERER=gl GTK_A11Y=none NO_AT_BRIDGE=1
  exec gtk4-widget-factory
'
```

Cerrar:

```bash
DISPLAY=:0 xdotool search --name "GTK Widget Factory" windowclose
```

### GPU

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc \
  'substrate-gpu-run blender'
```

---

## 4. Pruebas de estabilidad

### 4.1 Apertura/cierre GTK4

1. `gnome49 status`.
2. Abrir Text Editor.
3. Esperar 30 s.
4. Comprobar shell vivo.
5. Cerrar con `xdotool windowclose`.
6. Comprobar shell y `SHELL_EXIT`.

Resultado de la instantánea: **OK**.

### 4.2 Idle

Se probó un idle de **120 s** con la UI viva. En el modo actual:

```bash
SP=$(cat "$PREFIX/tmp/rt-dex/shell49.pid")
sleep 120
kill -0 "$SP" && echo VIVO
gnome49 status
```

Android puede congelar Termux si se apaga la pantalla; `gnome49` activa `termux-wake-lock` y, si hay ADB, `stayon`.

### 4.3 GPU

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc \
  'substrate-gpu-run glxinfo -B'
```

Debe aparecer **zink Vulkan 1.4 (Adreno (TM) 830v1 (MESA_TURNIP))** y **OpenGL 4.6**. Si aparece llvmpipe, se está usando el escape hatch `GNOME49_SW=1` o un perfil software.

### 4.4 Hardware + GTK4 (experimental)

Se observó:

- `FD_MESA_DEBUG=nolrz` permite sesiones de **30–60 s** con GTK4.
- En otras ejecuciones el shell murió a los 2 s.
- No es determinista; **no usar como modo por defecto**.

---

## 5. Logs

| Log | Qué contiene |
|---|---|
| `/tmp/rt-dex/shell49.log` | stdout/stderr del shell, warnings, `SHELL_EXIT=...` |
| `/tmp/rt-dex/session49-launch.log` | arranque de la sesión, servicios, errores |
| `/tmp/rt-dex/keyring.log` | keyring |
| `/tmp/rt-dex/gsd-*.log` | settings daemons |
| `/tmp/rt-dex/portal.log` | xdg-desktop-portal |
| `/tmp/rt-dex/app-*.log` | apps de prueba |
| `/tmp/rt-dex/polkitd.log` | polkitd |

Comandos:

```bash
tail -40 "$PREFIX/tmp/rt-dex/shell49.log"
grep -n 'SHELL_EXIT' "$PREFIX/tmp/rt-dex/shell49.log" | tail
tail -40 "$PREFIX/tmp/rt-dex/session49-launch.log"
```

`SHELL_EXIT=137` significa SIGKILL (no error de Python/JS). `139` sería SIGSEGV.

---

## 6. Si el shell muere

1. No matar Termux/X.
2. Comprobar X:

   ```bash
   DISPLAY=:0 xdpyinfo >/dev/null && echo X_OK
   ```

3. Reiniciar:

   ```bash
   gnome49 --restart
   ```

4. Si falla, leer:

   ```bash
   tail -60 "$PREFIX/tmp/rt-dex/shell49.log"
   tail -60 "$PREFIX/tmp/rt-dex/session49-launch.log"
   ```

5. Si X no responde, pedir a la persona que abra **Termux:X11** y ejecutar:

   ```bash
   nohup termux-x11 >/dev/null 2>&1 &
   sleep 12
   DISPLAY=:0 xdpyinfo
   ```

6. No reinstalar nada hasta identificar el error.

---

## 7. Si `/tmp/rt-dex` se borra

`gnome49` intenta restaurar los scripts desde:

```
~/.local/share/substrate/rt-dex/
```

Comprobar:

```bash
ls -l "$HOME/.local/share/substrate/rt-dex/"
```

Si faltan, copiar desde `scripts/` del repo y relanzar.

---

## 8. Parada segura

```bash
gnome49-stop
```

Debe:

- detener shell y servicios por PID;
- conservar X;
- no tocar SSH/tmux/OpenCode/Termux.

Verificar:

```bash
ps -eo pid,comm,args | grep -E 'gnome-shell|session-inner|session49' | grep -v grep
```

Si queda una app GTK4 o `gnome-text-editor --gapplication-service`, cerrarla por PID exacto, nunca por patrón amplio.

---

## 9. Evidencia de esta instantánea

- `evidence/01-editor-dark-software-shell.png` — Text Editor GTK4 oscuro, traffic lights, dock, shell software.
- `evidence/02-escritorio-limpio.png` — escritorio limpio, wallpaper MacTahoe day.
- `evidence/03-widgetfactory-hardware-nolrz.png` — Widget Factory con hardware + nolrz (experimental).
- `evidence/04-editor-software.png` — Text Editor en shell software.
- `evidence/05-calculator-software.png` — Calculator en shell software.

---

## 10. Criterios de aceptación

Una sesión se considera buena solo si:

- `gnome49 status` muestra shell y WM;
- captura con >100.000 colores;
- Text Editor GTK4 abre y cierra;
- el shell sigue vivo después del cierre;
- no hay ventanas de prueba al arrancar;
- SSH/tmux/OpenCode/Termux siguen vivos;
- no se usó `pkill -f`.

---

## 11. Qué no probar sin leer issues

- Forzar `GSK_RENDERER=ngl` (mata el shell) o quitar `GTK_A11Y=none`.
- `COGL_DEBUG` masivos sin backup.
- `strace -f` anidado bajo proot: puede dejar el shell en `tl` y UI negra.
- Perfetto/perf para señales: sin root no hay `signal_generate`.
- Cambiar el shell a `dexuser` sin probar D-Bus, X y apps.
- Instalar PipeWire/Bluetooth esperando que funcionen.

---

## 12. Estado de pruebas actual

| Prueba | Resultado |
|---|---|
| `gnome49 --restart` | OK |
| `gnome49 status` | OK |
| Color de captura | 93.315–94.847 |
| Compositor | Zink/Turnip, `kgsl_fds=1` |
| Text Editor GTK4 30 s + cierre | OK (`GSK_RENDERER=gl`) |
| Calculator GTK4 | OK (pruebas previas) |
| Widget Factory GTK4 | OK con hardware/nolrz 60 s (experimental) |
| Idle 120 s | OK |
| `xclock`/`zenity` | OK con hardware |
| LibreOffice | abre; renderizado estable |
| `substrate-gpu-run glxinfo` | Adreno 830v1, OpenGL 4.6 |
| GPU shell con GTK4 | **fallo intermitente; no por defecto** |
