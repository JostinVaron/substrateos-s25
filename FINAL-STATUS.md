# FINAL STATUS — SubstrateOS S25

**Fecha:** 2026-11-17  
**Estado:** GNOME Shell 49 X11 con **compositor GPU Zink/Turnip**, **ventanas de
apps visibles y pixel-exactas** (`COGL_DISABLE_TFP=1`, I-11), apps GTK4 con
`GSK_RENDERER=gl`, audio por PulseAudio+TCP, batería real y brillo por ADB.
I-01 cerrado; I-11 cerrado; **I-12 abierto** (SIGKILL silencioso ~13% en arranque
en frío, mitigación = supervisor pendiente).

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

## Parche definitivo V3 (2026-11-17, tarde) — apps visibles

**Problema:** las apps abrían pero no se veían ("plano invisible"); el escritorio
sí. Las instantáneas anteriores lo daban por bueno porque medían **colores de la
región** de la ventana — falso positivo: el wallpaper detrás también tiene 40k+
colores.

**Causa raíz (medida):** Termux:X11 anuncia DRI3 pero el open del dispositivo
falla (`MESA-EGL: DRI3 error: Could not get DRI3 device`). Mutter X11 compone
ventanas con GLX texture-from-pixmap; sin DRI3 no puede importar los pixmaps del
servidor → actores sin contenido → invisibles. El shell UI se dibuja
client-side (por eso se veía).

**Fix en producción:** `export COGL_DISABLE_TFP=1` en
`/etc/profile.d/zz-adreno-gpu.sh` (mutter lee cada ventana por CPU en cada damage
y la compone igual; stage/efectos siguen en GPU). Se eliminó el
`unset COGL_DISABLE_TFP` de `session49.sh` (quedaba de experimentos previos).

**Evidencia:**
- Gate RMSE (`scripts/distro/test-visibilidad.sh`) sobre `xlogo`: **RMSE=0,
  AE=0 de 62 500 píxeles**; tras mover la ventana RMSE=0 en la nueva posición y
  la vieja queda limpia (damage vivo).
- Antes/después: `evidence/17-app-invisible-antes.png` /
  `evidence/18-app-visible-despues.png`; transcripción en
  `evidence/16-visibilidad-rmse.txt`.
- Coste: shell **0.0% CPU en idle**; con animación pesada ~600% CPU agregado
  (readback por damage).
- Backups: `/etc/profile.d/zz-adreno-gpu.sh.pre-tfp-*`; copias en
  `/tmp/rt-dex/` y `~/.local/share/substrate/rt-dex/`.

**Pendientes que abre (I-12 y opcionales) — ⛔ CONGELADOS, NO EJECUTAR:**
1. Supervisor auto-curativo: **se implementó y se revirtió** (commits `b44179a`,
   `6c71cf9`; reverts `0be9344`, `025b89c`) porque provocaba reinicios en bucle y
   shell negro. Ante muerte del shell: `gnome49 --restart` **manual**.
2. Series de variantes (`TU_DEBUG`, `WSI`) — **no ejecutar**: el screening rompió
   la estabilidad. La tasa 2/15 del cold boot queda documentada, sin mitigar.
   Datos crudos: `evidence/14-boot-series.csv`, `evidence/15-watcher-muerte-boot8.txt`.
3. Ruta zero-copy (TFP nativo con Mesa de Termux) — **no ejecutar** en esta
   config congelada; queda como idea futura.
4. Reglas permanentes que SÍ aplican: toda verificación de visibilidad usa RMSE,
   nunca conteo de colores. `gnome-control-center` requiere
   `XDG_CURRENT_DESKTOP=ubuntu:GNOME` y aún aborta en `cc_object_storage`
   (usar paneles individuales).

## Rollback

- Código: `git revert` del commit de Zink.
- Scripts: copias `.pre-zink-*` en `/tmp/rt-dex` y respaldo persistente en
  `~/.local/share/substrate/rt-dex/`.
- Sesión: `GNOME49_SW=1 gnome49 --restart` (estado dorado anterior).
- GPU: restaurar `zz-adreno-gpu.sh` desde `zz-adreno-gpu.sh.golden-sw-*`.
