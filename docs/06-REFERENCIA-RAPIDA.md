# Referencia rápida

## Arrancar

```bash
nohup termux-x11 >/dev/null 2>&1 &
sleep 12
DISPLAY=:0 xdpyinfo >/dev/null && echo X_OK
gnome49
```

## Estado

```bash
gnome49 status
```

Esperado: shell + WM + `kgsl_fds=0` (software).

## Reiniciar / parar

```bash
gnome49 --restart
gnome49-stop
```

## Captura

```bash
proot-distro login ubuntu-gnome --shared-tmp -- bash -lc \
  'DISPLAY=:0 scrot -o /tmp/rt-dex/captura.png'
```

## Color de la captura

```bash
proot-distro login ubuntu-gnome --shared-tmp -- bash -lc '
  python3 -c "from PIL import Image; im=Image.open(\"/tmp/rt-dex/captura.png\").convert(\"RGB\"); print(len(im.getcolors(maxcolors=10000000)))"
'
```

## Text Editor (GTK4)

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc '
  export HOME=/home/dexuser DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/rt-dex
  export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/rt-dex/session-bus.addr)
  export GSK_RENDERER=cairo GTK_A11Y=none NO_AT_BRIDGE=1
  exec gnome-text-editor
'
```

## Cerrar ventana

```bash
proot-distro login ubuntu-gnome --shared-tmp -- bash -lc \
  'DISPLAY=:0 xdotool search --name "Text Editor" windowclose'
```

## GPU

```bash
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc \
  'substrate-gpu-run glxinfo -B'
```

## Blender

```bash
proot-distro login ubuntu-gnome --shared-tmp -- bash -lc 'apt install -y blender'
proot-distro login ubuntu-gnome --shared-tmp --user dexuser -- bash -lc \
  'substrate-gpu-run blender'
```

## Logs

```bash
tail -40 "$PREFIX/tmp/rt-dex/shell49.log"
tail -40 "$PREFIX/tmp/rt-dex/session49-launch.log"
grep -n 'SHELL_EXIT' "$PREFIX/tmp/rt-dex/shell49.log" | tail
```

## Rutas

```
$PREFIX/bin/gnome49
$PREFIX/bin/gnome49-stop
$PREFIX/tmp/rt-dex/
$PREFIX/var/lib/proot-distro/containers/ubuntu-gnome/rootfs/
/home/dexuser/.themes/MacTahoe-Dark/
/home/dexuser/.config/gtk-4.0/
/usr/local/bin/substrate-gpu-run
/etc/profile.d/zz-adreno-gpu.sh
```

## Prohibido

```bash
pkill -f ...
```

Usar PID exacto. No matar `sshd`, `tmux`, `termux`, `node`, `opencode`, `sv`.

## Estado de rendering

| Componente | Render |
|---|---|
| gnome-shell | llvmpipe/swrast |
| GTK4 | Cairo, software |
| Blender/ArtCraft | Adreno freedreno/kgsl |
| X11 | Termux:X11 |

## Documentos

- `README.md`
- `FINAL-STATUS.md`
- `docs/00-IDENTIDAD.md`
- `docs/01-ARQUITECTURA.md`
- `docs/02-INSTALACION-LIMPIA.md`
- `docs/03-APPS-GPU.md`
- `docs/04-OPERACION-TESTS.md`
- `docs/05-ISSUES-ROADMAP.md`
