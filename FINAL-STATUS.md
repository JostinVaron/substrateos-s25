# FINAL STATUS — SubstrateOS S25

**Fecha:** 2026-11-17  
**Estado:** GNOME Shell 49 X11 con **compositor GPU Zink/Turnip**, apps GTK4
estables (`GSK_RENDERER=gl`), audio por PulseAudio+TCP, batería real y brillo
por ADB. I-01 cerrado.

> Los PID son volátiles. Comprobar siempre con `gnome49 status`.

## Sesión actual (arranque en frío verificado)

| Campo | Valor |
|---|---|
| `gnome-shell` | PID **21254** (volátil) |
| X | `:0`, 1040x704 (ventana Termux:X11) |
| WM | GNOME Shell OK |
| Compositor | **Zink sobre Turnip** (`GALLIUM_DRIVER=zink`) |
| `kgsl_fds` | **1** |
| `/proc/<shell>/maps` | `zink`/`vulkan_freedreno` ×4, `llvmpipe`=0, `swrast`=0 |
| `GSK_RENDERER` | **gl** (apps GTK4) |
| `GTK_A11Y` / `NO_AT_BRIDGE` | none / 1 |
| `PULSE_SERVER` | `tcp:127.0.0.1:4713` |
| Shell user | root dentro del proot (I-02 abierto) |
| Home lógico | `/home/dexuser` |
| Tema | MacTahoe-Dark; iconos MacTahoe-dark; wallpaper MacTahoe-day |
| Captura | **92 762 colores** (`13-arranque-frio-zink.png`) |
| Ventanas de prueba | ninguna |

## Comandos

```bash
gnome49            # arranca / garantiza sesión (audio incluido)
gnome49 status     # estado + WM + kgsl + ventanas
gnome49 --restart  # reinicia completo (X intacto)
gnome49-stop       # detiene sesión; conserva X
GNOME49_SW=1 gnome49 --restart   # escape hatch llvmpipe/swrast + Cairo
```

## Evidencia de las fases (2026-11-17)

| Prueba | Resultado |
|---|---|
| Baseline software | 475–490 FPS, 90 268 colores, RSS 326 MB |
| Compositor Zink | 120 FPS vblank, 93 315 colores, RSS 242 MB |
| Stress I-01 (2 bloques) | 0 SIGKILL |
| Soak 10 min | `VIVO` |
| 10 min con Text Editor GTK4 | `VIVO` (87 145 colores, `12-idle-gtk4-10min.png`) |
| Blender 5.0.1 | ventana + shell vivo (`09-blender-zink.png`) |
| Audio | `paplay` rc=0, volumen 50 %, sink `AAudio_sink` |
| Batería | 56–58 %, discharging, 3.91 V, ~5 h (`upower-stub`) |
| Brillo | 101→90→101; atajos Super+F1/F2 |
| Arranque en frío | OK (`13-arranque-frio-zink.png`) |

## Pendiente de confirmación humana

1. Audio **audible** en el altavoz (servidor/sink activos; el agente no oye).
2. Pulsar `Super+F1` / `Super+F2` para confirmar el cambio de brillo.
3. Fase 5 (`dexuser`): no ejecutada; opcional/no bloqueante, requiere sesión
   parada, `chown` y rollback. I-02 sigue abierto.
4. I-06: chevron Wi‑Fi en MacTahoe (CSS del tema), documentado como limitación.

## Rollback

- Código: `git revert` del commit de Zink.
- Scripts: copias `.pre-zink-*` en `/tmp/rt-dex` y respaldo persistente en
  `~/.local/share/substrate/rt-dex/`.
- Sesión: `GNOME49_SW=1 gnome49 --restart` (estado dorado anterior).
- GPU: restaurar `zz-adreno-gpu.sh` desde `zz-adreno-gpu.sh.golden-sw-*`.
