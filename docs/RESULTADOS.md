# Resultados — Plan de estabilización one-shot (SubstrateOS S25)

**Fecha de ejecución:** 2026-11-20 (08:02–08:13 UTC)
**Dispositivo:** Samsung Galaxy S25 `SM-S931B`, Snapdragon 8 Elite, Adreno 830, Android/OneUI
**Entorno:** Termux nativo + `proot-distro` `ubuntu-gnome` (Ubuntu 26.04.1 LTS, GNOME Shell 49.0 X11)
**Stack GPU:** Zink sobre Turnip (Mesa 26.3.0-devel), `COGL_DISABLE_TFP=1`
**Rama:** `fix/stability-plan`

## Veredicto

`GATE_PASS` en Fase 0, 1, 2, 3, 4, 4.1, 4.2, 5, 6 y 7. Soak de **601 s** con `gnome-text-editor` (GTK4) abierto: **`deaths=0`**, **`shell_exits=0`**, `gnome-shell` vivo al cierre (**11:16** de uptime). Captura final con **51.623 colores**.

## Benchmarks (antes vs. después)

| Métrica | Antes | Después (medido) |
|---|---|---|
| Estabilidad del compositor | `SHELL_EXIT=137` a los ~5–6.5 min; pantalla negra | **601 s de soak, `deaths=0`, `shell_exits=0`** |
| GPU renderer | `zink Vulkan 1.4(Adreno (TM) 830v1 (MESA_TURNIP))`, caídas a `llvmpipe` | **`zink Vulkan 1.4(Adreno (TM) 830v1 (MESA_TURNIP))`, OpenGL ES 3.2, `kgsl_fds=1`, `zink_maps=4`, `sw_maps=0`** |
| Gate de visibilidad | `RMSE=0` solo con `COGL_DISABLE_TFP=1` | **`RMSE=0 (0)`, `VEREDICTO: VISIBLE`** |
| Arranque a escritorio (`gnome49 --restart`) | N/D | **19 s** |
| `glmark2-es2` (800x600) | No instalado | **492 puntos** |
| Memoria disponible (`free -m`) | 3830 MB (shell muerto) | **3508 MB (GNOME vivo + editor; no comparable 1:1)** |
| Censo fantasma OneUI | 53 procesos | **11–12 con Termux en primer plano; ≤32 con Termux:X11** |

## Evidencia cruda (Fase 7)

```text
[BENCH] boot_seconds=19
[BENCH] glmark2_score=492
    GL_RENDERER:    zink Vulkan 1.4(Adreno (TM) 830v1 (MESA_TURNIP))
    GL_VERSION:     OpenGL ES 3.2 Mesa 26.3.0-devel (git-98f3d6229d)
[BENCH] free_mb=3508 shell_pid=29118 shell_rss_kb=219352 kgsl_fds=1
[SOAK] min=10 shell=ALIVE pid=29118 (init=29118)
[SOAK] deaths=0
[SOAK] soak_seconds=601
[SOAK] shell_exits=0
[SOAK] final_screenshot=/tmp/rt-dex/final-soak-10min.png colors=51623
[GATE-7] pid=29118 kgsl_fds=1 zink_maps=4 sw_maps=0
GATE_PASS: FASE 7 COMPLETADA
```

Captura final: [`docs/evidence/final-soak-10min.png`](docs/evidence/final-soak-10min.png) (1032x612, 51.623 colores).

## Checklist de aceptación

- [x] `DISPLAY=:0 xdpyinfo` devuelve `0` (`phase-0.log`).
- [x] Backup de 34 archivos verificado con `sha256sum -c` (`phase-1.log`).
- [x] Demonios inútiles desactivados (`ollama` en `down`; 15 servicios D-Bus en `.disabled-substrate`; `dbus-daemon` vivos = 2) (`phase-2.log`).
- [x] Blindaje Android por ADB dinámico (`monitor_phantom_procs=false`, `max_phantom=2147483647`, `freezer=disabled`) (`phase-3.log`).
- [x] Censo fantasma reducido de 53 a 11–12 (`phase-4b.log`, `phase-4c.log`).
- [x] GPU Adreno 830 activa en todo el stack (`phase-4.log`, `phase-7.log`).
- [x] Gate de visibilidad pixel-exacta: `RMSE=0 (0)`, `VEREDICTO: VISIBLE` (`phase-4.log`).
- [x] Toolchain completo verificado en Ubuntu (`phase-5.log`).
- [x] Apariencia MacTahoe-Dark y fuentes AMOLED aplicadas sin duplicados (`phase-6.log`).
- [x] **Captura `scrot` con >10 colores**: 51.623 colores (`phase-7.log`).
- [x] **`gnome-shell` vivo tras 10 minutos de uso** con app GTK4 abierta (`phase-7.log`).

## Causa raíz dominante

Samsung OneUI impone un límite duro de ~32 procesos fantasma. Al superarlo mata el proceso más nuevo o de mayor CPU, normalmente `gnome-shell` (`SHELL_EXIT=137`). Los ajustes `settings_enable_monitor_phantom_procs=false`, `max_phantom_processes=2147483647` y `cached_apps_freezer=disabled` **son ignorados** por OneUI. La solución efectiva fue reducir el censo (Fase 4.1/4.2): retirar `runsv` apagados, enmascarar IBus, portales, `gvfsd`, `accounts-daemon`, `colord`, `wpa_supplicant`, `ModemManager` y `gjs`, y activar `polkitd` por D-Bus en vez de un supervisor.

## Logs

| Fase | Log |
|---|---|
| 0 | `/tmp/rt-dex/phase-0.log` |
| 1 | `/tmp/rt-dex/phase-1.log` |
| 2 | `/tmp/rt-dex/phase-2.log` |
| 3 | `/tmp/rt-dex/phase-3.log` |
| 4 | `/tmp/rt-dex/phase-4.log` |
| 4.1 | `/tmp/rt-dex/phase-4b.log` |
| 4.2 | `/tmp/rt-dex/phase-4c.log` |
| 5 | `/tmp/rt-dex/phase-5.log` |
| 6 | `/tmp/rt-dex/phase-6.log` |
| 7 | `/tmp/rt-dex/phase-7.log` |

## Reproducir

El procedimiento completo, idempotente y con gates por fase está en [`PLAN.md`](PLAN.md). La Fase 4.1/4.2 es obligatoria: sin ella el censo vuelve a superar 32 y OneUI mata `gnome-shell`.
