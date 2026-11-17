# 07 — ArtCraft: informe de diagnóstico y estado (2026-11-17)

Informe rápido del trabajo sobre la suite ArtCraft (issue #4). Todo lo afirmado
está medido; lo no resuelto se marca como **ABIERTO**.

## Resumen en una línea

El "no abre" era un FIFO roto en el lanzador del dock (**ARREGLADO**). La
"inestabilidad" es un SIGKILL de Android a procesos nuevos de Termux
(~40–60 s) que **no se reproduce** cuando la app nace anclada a tmux
(**MITIGACIÓN IMPLEMENTADA, validación final pendiente**).

## 1. Causa raíz del "no abre" (ARREGLADO)

- Los `.desktop` de la suite ejecutaban `artcraft-broker-client`, que escribía a
  `/tmp/launch.fifo`, pero el broker usa `/tmp/broker/launch.fifo`.
- Como `/tmp/launch.fifo` no existía, la redirección `>` creaba un **archivo
  regular** (verificado: 12 bytes, escrito por un clic real del humano). `printf`
  devolvía rc=0 → el fallback `|| exec` nunca corría → **exit 0 silencioso**.
- Bug adicional en el broker: `[ ! -x "$APP" ] && continue` descartaba
  `filmcraft` (nombre, no ruta) incluso con el FIFO correcto.

**Fix aplicado (nivel app, sin tocar config congelada):**

| Archivo | Cambio |
|---|---|
| `/usr/local/bin/artcraft-suite-run` (nuevo) | wrapper directo: log + `substrate-gpu-run <app>`; para filmcraft añade `--graphics low-power` |
| `/usr/local/bin/artcraft-broker` | FIFO correcto, sin el filtro roto, protocolo `<app> [args...]`, lanza vía `artcraft-suite-run` |
| `/usr/local/bin/artcraft-broker-client` | escribe al FIFO real si existe; si no, fallback directo |
| 5 `.desktop` (`ai.storyteller.*`) | `Exec=/usr/local/bin/artcraft-broker-client <app>` |
| `/tmp/launch.fifo` | eliminado (archivo trampa) |

**Evidencia:** log del wrapper con `launch app=filmcraft ppid=24971`
(gnome-shell) y ventana mapeada (ver §3).

## 2. Inestabilidad: SIGKILL a los ~40–60 s (ABIERTO, mitigado)

Mediciones:

| Lanzamiento | Parenting | Resultado |
|---|---|---|
| `proot-distro login` efímero | bash de turno | SIGKILL a +41 s, +60 s, +130 s |
| tmux (pane persistente) | tmux server | vivo >2.5 min y >5 min (cerrado por mí) |
| dock (gnome-shell) | gnome-shell | muere a **~53 s** |

- Muere con **SIGKILL** (bash reporta `Killed`=137) en estado `R` tras un burst de
  CPU, con `oom_score_adj=0`, RSS estable (~120–170 MB) y 4 GB libres: **no es OOM**.
- logcat (Shizuku/`rish`) no muestra `am_kill`, ni `lowmemorykiller`, ni "Killing";
  los procesos aparecen como `PhantomProcessRecord {…:16094:…}` (Android trata los
  hijos de Termux como *phantom processes*).
- Los knobs estándar ya estaban desactivados y **no bastan**:
  `settings_enable_monitor_phantom_procs=false`,
  `max_phantom_processes=2147483647`.
- **Hipótesis fuerte:** no se puede afirmar el asesino exacto (no firma en logs),
  pero el patrón es consistente con gestión de procesos de Android/OneUI sobre
  hijos nuevos de Termux; el parent longevo (tmux) lo evita empíricamente.

**Mitigación implementada (FASE 2B del issue):** broker anclado a tmux +
protocolo FIFO corregido + `.desktop` → broker-client. Validado el mecanismo
(cliente → FIFO → broker → app viva + ventana mapeada). **Pendiente:** clic real
desde el dock y soak de 10 min.

Arranque manual del broker tras cada sesión:

```bash
tmux new-window -d -n artcraft-broker \
  'proot-distro login ubuntu-gnome --shared-tmp -- /usr/local/bin/artcraft-broker'
```

## 3. Visibilidad y wedge del compositor

- La ventana de FilmCraft **sí es visible** cuando abre: `Map State: IsViewable`,
  tema oscuro real (≈19k colores en la región; 87k en la medición a 2000×1200).
- `test-visibilidad.sh` da **falso "SOSPECHOSA"** (RMSE≈5926, AE 8.1%):
  es una franja 725×72 (strip de video) que `import -window` no ve. No es I-11.
- **Riesgo real:** `import -window` contra la ventana de FilmCraft (mutter hace
  CPU-readback a 120 Hz por `COGL_DISABLE_TFP`) puede **wedgear el compositor**:
  panel congelado, ninguna ventana nueva mapea (xclock `IsUnMapped`). Ocurrió 2
  veces (una con el clic real del humano + gestor de tareas). **No usar
  `import -window` sobre FilmCraft.** Recuperación: `gnome49 --restart`
  (una vez falló con `SHELL_EXIT=137` por I-12; el reintento funcionó).
- Con `--graphics low-power` el wedge no se reprodujo en las pruebas (2.5 y 5+ min).

## 4. Limitaciones / pendientes

1. **Asesino del SIGKILL no identificado al 100%** (sin firma en logcat; knobs ya
   puestos). La mitigación es empírica (anclaje), no una corrección del origen.
2. **El broker no persiste tras reinicio** del teléfono/sesión: hay que abrir el
   pane tmux (comando arriba). No se puede automatizar en `session-inner.sh`
   (config congelada).
3. **Validación final pendiente**: clic desde dock + soak 10 min.
4. **Solo FilmCraft probado**. LightCraft, VectorCraft, PhotoCraft, EffectCraft no
   se han abierto todavía; `craft-anything` no tiene binario instalado
   (su `.desktop` quedaría inerte).
5. **Launcher GUI** (`artcraft-launcher`): red OK; instalación system-wide requiere
   pkexec (127) — ya resuelto a mano (`artcraft-install-fallback`); no re-probar.
6. **Audio**: la app no ve salida ALSA (`no audio output device found`); el audio
   del sistema va por PulseAudio TCP. No bloqueante.
7. **Resolución X cambió** durante las pruebas (2000×1200 → 1008×676, lado usuario):
   las métricas de colores no son comparables entre capturas.
8. No se tocó config congelada ni se instaló/desinstaló nada del sistema.

## 5. Reproducir la verificación

```bash
gnome49 status
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'DISPLAY=:0 xdpyinfo >/dev/null && echo X_OK'
# panel animando (bbox != None)
proot-distro login ubuntu-gnome --shared-tmp -- bash -c 'DISPLAY=:0 scrot -o /tmp/rt-dex/a.png; sleep 65; DISPLAY=:0 scrot -o /tmp/rt-dex/b.png; python3 -c "
from PIL import Image, ImageChops
print(ImageChops.difference(Image.open(\"/tmp/rt-dex/a.png\").convert(\"L\").crop((0,0,1008,40)), Image.open(\"/tmp/rt-dex/b.png\").convert(\"L\").crop((0,0,1008,40))).getbbox())"'
# tras un clic en el dock: wmctrl -l debe listar FilmCraft y el panel debe seguir animando
```
