# Issues, límites y roadmap

## 1. Issues abiertos

### I-01 — `SIGKILL` del compositor con GTK4 (hardware)

**Estado:** **cerrado** (2026-11-17). Compositor acelerado Zink/Turnip estable.  
**Severidad:** resuelta; el modo por defecto ya es hardware.

Síntoma original:

- `gnome-shell` recibía `SIGKILL` (`SHELL_EXIT=137`) al mapear una ventana GTK4
  con el compositor freedreno-gallium.
- Ocurría con Text Editor, Calculator y Widget Factory.
- No ocurría con `xclock`, `zenity` (GTK3) ni, en general, GTK3.

Diagnóstico final (medido):

- La ruta **freedreno-gallium** moría al componer superficies ARGB/GTK4.
- **Zink sobre Turnip** (Vulkan, `/dev/kgsl-3d0`) usa otro stream de comandos y
  no dispara el fallo: `direct rendering: Yes`,
  `Device: zink Vulkan 1.4 (Adreno (TM) 830v1 (MESA_TURNIP))`, GL 4.6.
- El SIGKILL que se veía en el stress inicial de la migración **no era GPU**:
  Android mató el árbol de la sesión durante una explosión de procesos
  at-spi/ibus. Con `GTK_A11Y=none` + `NO_AT_BRIDGE=1` el patrón desaparece.
- `GSK_RENDERER=ngl` sigue matando el shell; **`gl` es el renderer válido**
  sobre Zink. `cairo` queda como fallback.

Configuración ganadora:

```sh
# /etc/profile.d/zz-adreno-gpu.sh (v4)
GALLIUM_DRIVER=zink
MESA_LOADER_DRIVER_OVERRIDE=zink
LIBGL_ALWAYS_SOFTWARE=0
MESA_VK_WSI_PRESENT_MODE=immediate
# session-inner.sh
GSK_RENDERER=gl
GTK_A11Y=none
NO_AT_BRIDGE=1
```

Evidencia:

- `kgsl_fds=1`, `zink|vulkan_freedreno` ×4 en `/proc/<shell>/maps`,
  `llvmpipe=0`, `swrast=0`.
- 2 bloques de stress: 5× editor, 3× Widget Factory, 3× calculadora,
  arrastre + 5 cambios de escritorio; **0 muertes**.
- Soak de 10 min: `VIVO`.
- 10 min con Text Editor GTK4 abierto: `VIVO`, `SHELL_EXIT=137` ausente.
- Blender 5.0.1: ventana mapeada, captura 94 847 colores, shell vivo.
- Benchmark: 475–490 FPS software → **120 FPS vblank-locked**, RSS 326→242 MB.
- Capturas en `evidence/05-mactahoe-zink.png`, `06-blender-zink.png`.

Rollback / escape hatch:

- `GNOME49_SW=1 gnome49 --restart` restaura llvmpipe/swrast + Cairo.
- Backups `.pre-zink-*` en `/tmp/rt-dex` y en el respaldo persistente.

### I-02 — Notificación “Logged in as a privileged user”

**Estado:** abierto (no bloqueante).  
**Causa:** `gnome-shell` corre como root dentro del proot; GNOME lo detecta y avisa.  
**Impacto:** cosmético/seguridad; no rompe apps.

Intentos:

- Ejecutar la sesión como `dexuser`: arrancó, pero en una prueba Text Editor no mapeó ventana y el shell murió al abrir una app; se revirtió (ver `restart49.sh.pre-dexuser-*`).
- El texto está dentro de `libshell-17.so`; no hay gsetting directo.

Futuro:

- Resolver la sesión completa como `dexuser` con D-Bus, X, /tmp y portales
  (precondición: `chown -R dexuser:dexuser /home/dexuser /tmp/rt-dex` con la sesión parada).
- O parchear el aviso en GNOME Shell (no recomendado como primera opción).

### I-03 — Audio/volumen

**Estado:** **cerrado** (2026-11-17).  
PulseAudio 17 de Termux con `module-aaudio-sink`. El proot **no puede** usar el
socket unix (proot rompe SCM_RIGHTS → `Protocol error`), así que se usa el
puente **TCP loopback**:

```sh
# Termux (~/…/usr/etc/pulse/default.pa)
load-module module-native-protocol-tcp port=4713 auth-anonymous=1 listen=127.0.0.1
# sesión proot (session-inner.sh)
PULSE_SERVER=tcp:127.0.0.1:4713
```

`substrate-audio-up` (Termux) arranca/verifica PulseAudio antes de cada sesión;
`gnome49` lo invoca. `paplay` de `bell.oga` desde el proot devuelve 0 y
`pactl set-sink-volume @DEFAULT_SINK@ 50%` aplica el slider.

Pendiente de confirmación humana: que el sonido sea **audible** en el altavoz
(el servidor y el sink están activos; la app no puede oír).

### I-04 — Bluetooth

**Estado:** bloqueado.  
No hay adaptador BlueZ ni `/dev/rfkill`; el tile no aparece.

Futuro:

- Compartir un adaptador USB/Android (no disponible).
- Simulación solo cosmética; no recomendable.

### I-05 — Brillo/batería

**Estado:** **cerrado** para la parte real; cosmético Wi-Fi sigue en I-06.  
Implementado:

- **Batería:** `upower-stub.py` sustituye a `upowerd` y sirve
  `org.freedesktop.UPower` con `termux-battery-status` cada 60 s
  (Percentage, State, Energy, Voltage, Temperature, TimeToEmpty).
  Medido en vivo: 56–58 %, `discharging`, 3.91 V, 29–31 °C.
- **Brillo:** `/usr/local/bin/substrate-brightness` usa ADB inalámbrico
  (`settings put system screen_brightness`). Probado 101→90→101.
- Atajos `Super+F1` (−25) y `Super+F2` (+25) vía
  `org.gnome.settings-daemon.plugins.media-keys custom-keybindings`.

Pendiente: pulsar los atajos en el dispositivo (la sesión ya los tiene cargados).

### I-06 — Wi-Fi simulado y chevron

**Estado:** parcial.  
`nm-stub.py` muestra `SubstrateOS` y el tile Wi-Fi; el chevron del submenú no
abre en MacTahoe. El `gnome-shell.css` de MacTahoe-Dark solo define
`.popup-menu-content`; no hay reglas `popup-submenu`. Queda documentado como
limitación del tema (no se tocó CSS a ciegas).

Futuro:

- Corregir el popup del submenú en el tema (requiere inspección visual del árbol St).
- Conectar NetworkManager real si se puede compartir la red Android.

### I-07 — Root/dock y apps

**Estado:** parcial.  
El shell es root; apps del dock heredan root. Algunas apps (Nautilus en ciertos flujos) pueden rechazar root o comportarse distinto.

Futuro:

- Sesión como `dexuser` o wrapper de lanzamiento por app.
- `.desktop` con `substrate-gpu-run` para apps 3D.

### I-08 — Rendimiento del compositor

**Estado:** **cerrado** (2026-11-17).  
El escritorio compone en GPU vía Zink/Turnip: 120 FPS vblank-locked, shell con
242 MB RSS (antes 326 MB en software). `glxgears` software daba 475–490 FPS
sin vsync (número engañoso: CPU, no pantalla); ahora está limitado a 120 Hz.

Futuro:

- Reducir resolución/escala si se quiere más batería.
- Benchmark formal sostenido (30 min) y perfilado de CPU.
- Optimizar servicios y RAM.

### I-09 — Snap/Flatpak

**Estado:** no recomendado.  
proot no ofrece el entorno de namespaces/systemd que esperan. Preferir `.deb`/AppImage.

### I-10 — Apps que requieren systemd/logind real

**Estado:** limitado.  
Solo se simula lo mínimo. Apps que llamen a `systemctl` o logind avanzado pueden fallar.

### I-11 — Las apps abren pero no se ven ("plano invisible") — **CERRADO 2026-11-17**

**Estado:** resuelto (parche definitivo V3).  
**Severidad:** era total (ninguna ventana visible); ahora 0.

Síntoma (testimonio humano + medido): cualquier app abre (proceso vivo, ventana
mapeada, `wmctrl` la lista) pero no aparece en pantalla; el escritorio (panel,
dock, wallpaper) sí se ve.

**Error de medición que lo ocultó:** contar colores de la región de una ventana es
un **falso positivo** — el wallpaper tiene 40k+ colores. Los tests de la
instantánea anterior (incluidos `12-idle-gtk4-10min.png` y los del issue #1) usaban
ese método y reportaron éxito falso.

**Cadena causal (medida):**
1. Termux:X11 anuncia DRI3/Present, pero el open del dispositivo falla en cada
   cliente: `MESA-EGL: DRI3 error: Could not get DRI3 device` (en `shell49.log`).
2. Mutter X11 compone ventanas con **GLX texture-from-pixmap (TFP)**; sin DRI3 la
   textura del pixmap del servidor no se puede importar → actor sin contenido.
3. El shell UI sí se dibuja client-side (por eso el escritorio se veía).

**Fix (validado, en producción):**
`export COGL_DISABLE_TFP=1` en `/etc/profile.d/zz-adreno-gpu.sh`. Mutter lee las
ventanas por CPU (XGetImage) por damage y las compone igual; el stage/efectos
siguen en GPU (Zink/Turnip).
- Evidencia RMSE: **0 (0)** y AE **0 de 62 500 píxeles** (xlogo, sesión reiniciada
  limpia); tras mover la ventana RMSE=0 en la nueva posición y la vieja limpia.
- Coste: shell **0.0% CPU en idle**; con animación pesada (glxgears de fondo)
  ~600% CPU agregado (readback por damage).
- `proot-distro login` NO hereda env del host → el knob debe vivir en
  `zz-adreno-gpu.sh`/`session-inner.sh`. El `unset COGL_DISABLE_TFP` que había en
  `session49.sh` se eliminó (era de los experimentos previos).

**Protocolo nuevo (obligatorio):** `scripts/distro/test-visibilidad.sh` (RMSE
ventana-vs-pantalla). Ver `evidence/16-visibilidad-rmse.txt`.
Capturas: `evidence/17-app-invisible-antes.png` / `18-app-visible-despues.png`.

**Mejora opcional (⛔ aplazada — config congelada):** ruta zero-copy (TFP nativo)
con la Mesa de Termux 26.2.7 para eliminar el readback CPU. No ejecutar hasta
nuevo aviso.

### I-12 — SIGKILL silencioso en arranque en frío (~13%) — **ABIERTO / CONGELADO**

**Estado:** abierto; causa invisible sin root. **⛔ CONGELADO: no se trabaja en
esta configuración.**  
**Severidad:** media en la práctica (el humano reintenta con `gnome49 --restart`).

Medido en 15 arranques en frío instrumentados (2026-11-17): **2 muertes
(13.3%)**, siempre al pintar la UI inicial (~t+20–28 s), con `SHELL_EXIT=137`.

Eliminados por evidencia: phantom killer (monitor OFF y sin registros), lmkd,
ActivityManager (`am_kill`/`am_proc_died` ausentes), OOM (4.4 GB libres), cgroup-OOM
(el cgroup de la app no tiene controlador de memoria), faults de GPU
(`gpufaults=0 0 0 0 0 0 0 0`), scripts de arranque (solo hacen `wait`), X server
(vivo tras la muerte). El shell muere en estado `R`, GPU busy 8-10%, memoria plana.

Hipótesis abiertas (sin visibilidad de dmesg/`/proc/vmstat` sin root):
1. terminación por **HANG del driver kgsl** (`ft_policy=0xC2`, `ft_long_ib_detect=1`;
   sólo loguea a dmesg);
2. reaper silencioso de **Samsung Freecess** (Termux:X11 corre como
   PhantomProcessRecord hijo de com.termux).

Plan de mitigación (⛔ NO EJECUTAR — probado y revertido): se implementó un
supervisor con reintentos automáticos + screening de variantes (`TU_DEBUG=noubwc`,
`noltoc`, `MESA_VK_WSI_PRESENT_MODE=fifo`) en los commits `b44179a` y `6c71cf9`;
provocó reinicios en bucle y shell negro y se revirtió en `0be9344` y `025b89c`.
**La mitigación oficial es manual: ante shell muerto, `gnome49 --restart`.**
Datos crudos conservados: `evidence/14-boot-series.csv`,
`evidence/15-watcher-muerte-boot8.txt`.

---

## 2. Cosas que ya se descartaron

- **Perfetto/perf/simpleperf para señales:** sin root no hay `signal_generate`; el trace no sirve.
- **freedreno-gallium para el compositor:** muere con ARGB/GTK4. Sustituido por Zink/Turnip.
- **`FD_MESA_DEBUG=nolrz` como solución:** alargaba la vida, no eliminaba el fallo.
- **OOM/LMKD:** no aparece `am_kill`/`lmkd` relevante.
- **Phantom process killer como causa del fallo GTK4:** el monitor está desactivado
  y los máximos son enormes. Pero **sí** mató el árbol de la sesión durante el
  stress inicial: lo que moría era un pico de procesos at-spi/ibus, no la GPU.
  Con `GTK_A11Y=none` + `NO_AT_BRIDGE=1` desaparece.
- **`GSK_RENDERER=ngl`:** mata el shell al primer editor. `gl` es el bueno.
- **Cerrar con `wmctrl` como causa:** no era la causa.
- **D-Bus/portal como única causa:** se probó app sin bus y también murió.
- **CSD visible con `GTK_CSD=0`:** GTK4 lo ignora; no cambió el resultado.
- **Sombras CSS:** quitarlas no evitó el fallo.
- **Mesa de Termux / trasplantes:** innecesario; el Mesa del distro ya trae
  `kgsl_dri.so`, `zink_dri.so` y Turnip.
- **PipeWire bajo proot:** bucle `ENOSYS`; se usa PulseAudio + TCP loopback.

---

## 3. Roadmap sugerido

### Corto plazo

1. Congelar la configuración estable actual y usarla.
2. Añadir benchmarks (`glxgears`, CPU idle, tiempo de arranque, RAM).
3. Crear `.desktop` GPU para Blender/ArtCraft.
4. Documentar/automatizar backup de themes y scripts.
5. Verificar más apps GTK4 (Files, Settings, Software) con shell software.

### Medio plazo

1. Investigar LRZ/freedreno con Mesa upstream.
2. Probar Wayland/Weston como compositor alternativo.
3. Resolver sesión `dexuser` completa (D-Bus, X, portales, /tmp).
4. Mejorar audio (PulseAudio mínimo) sin bucles.
5. Añadir un menú/atajo “GPU app” que use `substrate-gpu-run`.

### Largo plazo

1. Compositor acelerado estable con GTK4.
2. Soporte de audio/batería/brillo vía Termux:API.
3. Perfil de rendimiento con benchmarks y ajustes de CPU/GPU.
4. Empaquetar la instalación como script idempotente.
5. Tests automáticos de arranque/apps/captura.

---

## 4. Criterios para declarar “resuelto” I-01

- [x] Compositor hardware (`kgsl_fds>=1`, `zink`/`vulkan_freedreno` en maps).
- [x] Abrir/cerrar Text Editor, Calculator y Widget Factory repetidamente
      (2 bloques de 5+3+3 con arrastre y cambios de escritorio).
- [x] 10 minutos de idle con ventana GTK4 abierta.
- [x] Sin `SHELL_EXIT=137` en la configuración final.
- [x] Captura con color (93 315 / 94 137 / 94 847 colores) y tema MacTahoe.
- [x] Apps GPU siguen usando Adreno (`substrate-gpu-run glxinfo -B`).
- [x] Sin regresiones en dock/tema (captura P2.4).

**Nota:** `GSK_RENDERER=ngl` no cumple; `gl` sí. `cairo` es fallback aceptado.

---

## 5. Riesgos

- Cambiar el compositor a hardware puede volver a matar el shell; no hacerlo sin backup.
- Cambiar usuario del shell puede romper buses/portales.
- Instalar apps que arrastren systemd/snap puede añadir ruido.
- Borrar `/tmp/rt-dex` sin respaldo rompe la restauración.
- Usar `pkill -f` puede tumbar la sesión SSH/OpenCode.
- Forzar `FD_MESA_DEBUG` sin probar puede ocultar o mover el fallo.
