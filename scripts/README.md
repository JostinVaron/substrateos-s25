# Scripts

## termux/

| Archivo | Destino real | Función |
|---|---|---|
| `gnome49` | `$PREFIX/bin/gnome49` | launcher, estado y verificación visual |
| `gnome49-stop` | `$PREFIX/bin/gnome49-stop` | parada segura |
| `restart49.sh` | `$PREFIX/tmp/rt-dex/restart49.sh` | reinicio completo |
| `mactahoe-on` | `$PREFIX/bin/mactahoe-on` | reactivar tema MacTahoe |
| `mactahoe-off` | `$PREFIX/bin/mactahoe-off` | desactivar tema (si existe) |

## distro/

| Archivo | Destino real | Función |
|---|---|---|
| `session49.sh` | `/tmp/rt-dex/session49.sh` | entorno, bus de sistema, fake-login1 |
| `session-inner.sh` | `/tmp/rt-dex/session-inner.sh` | gsd/portales/shell software |
| `zz-adreno-gpu.sh` | `/etc/profile.d/zz-adreno-gpu.sh` | receta GPU freedreno/kgsl |
| `substrate-gpu-run` | `/usr/local/bin/substrate-gpu-run` | wrapper de apps GPU |
| `fake-login1.py` | `/usr/local/share/substrate/fake-login1.py` | logind simulado |
| `nm-stub.py` | `/usr/local/share/substrate/nm-stub.py` | NetworkManager simulado |
| `gnome-moderno.sh` | `/usr/local/bin/gnome-moderno.sh` | launcher clásico de la distro |
| `substrate-flashback.sh` | `/usr/local/bin/substrate-flashback.sh` | rescate clásico |

## Notas

- Los scripts de `/tmp` se pierden al limpiar `/tmp`; `gnome49` los restaura desde `~/.local/share/substrate/rt-dex/`.
- Los scripts de `distro/` se copian al rootfs con `install`.
- No ejecutar estos scripts desde Termux nativo salvo los de `termux/`.
- `substrate-gpu-run` debe ejecutarse dentro del proot y con `--user dexuser` para apps de usuario.
