# Issues, límites y roadmap

## 1. Issues abiertos

### I-01 — `SIGKILL` del compositor con GTK4 (hardware)

**Estado:** abierto; mitigado con compositor software.  
**Severidad:** alta si se fuerza hardware; actualmente no afecta al modo por defecto.

Síntoma:

- `gnome-shell` recibe `SIGKILL` (`SHELL_EXIT=137`) al mapear una ventana GTK4 en el compositor acelerado.
- Ocurre con Text Editor, Calculator y Widget Factory.
- No ocurre con `xclock`, `zenity` (GTK3) ni, en general, GTK3.
- Con `FD_MESA_DEBUG=nolrz` sobrevive 30–60 s en algunas ejecuciones, pero también murió a los 2 s en otras.

Evidencia reunida:

- GTK4 usa CSD/ARGB; `_GTK_FRAME_EXTENTS` y `_NET_WM_OPAQUE_REGION`.
- `xclock`/zenity usan ventana con frame del WM o 24-bit; GTK4 no.
- `GSK_RENDERER=cairo`, `GTK_A11Y=none`, `NO_AT_BRIDGE=1` no bastan.
- `LIBGL_DRI3_DISABLE=1`, `COGL_DISABLE_TFP=1`, COGL debug flags y sombras CSS no bastan.
- `MUTTER_DEBUG_FORCE_LINEAR_BLENDING=1` alarga la vida, pero no elimina el fallo.
- El software compositor es estable.
- Perfetto no habilita `signal_generate` sin root; `perf` no puede abrir eventos; `strace` anidado deja el shell en `tl`.
- Phantom process killer fue descartado como causa primaria (monitor desactivado y máximos enormes; el patrón de muerte coincide con GPU/GTK4).

Hipótesis principal:

- Bug de **LRZ / compresión de render target / sRGB** en la ruta freedreno/kgsl al componer una superficie ARGB de GTK4. `nolrz` cambia el comportamiento, pero hay otra ruta afectada.

Mitigación actual:

- Compositor en llvmpipe/swrast.
- Apps GPU por `substrate-gpu-run`.
- No prometer compositor acelerado estable.

Posibles siguientes pasos:

1. Probar `FD_MESA_DEBUG=nolrzfc`, `nobypass`, `gmem`, `nopreempt`, combinaciones con linear blending.
2. Probar un compositor Wayland/GNOME bajo Weston (otra ruta de buffer).
3. Forzar server-side frame para GTK4 (parche Mutter/GTK4 o window wrapper).
4. Usar un compositor alternativo para el escritorio (sway/weston) y GNOME solo como apps.
5. Capturar GPU fault con `kgsl`/ftrace desde root o Shizuku si se habilita.
6. Reportar a Mesa freedreno con traza mínima.

### I-02 — Notificación “Logged in as a privileged user”

**Estado:** abierto.  
**Causa:** `gnome-shell` corre como root dentro del proot; GNOME lo detecta y avisa.  
**Impacto:** cosmético/seguridad; no rompe apps.

Intentos:

- Ejecutar la sesión como `dexuser`: arrancó, pero en una prueba Text Editor no mapeó ventana y el shell murió al abrir una app; se revirtió.
- El texto está dentro de `libshell-17.so`; no hay gsetting directo.

Futuro:

- Resolver la sesión completa como `dexuser` con D-Bus, X, /tmp y portales.
- O parchear el aviso en GNOME Shell (no recomendado como primera opción).

### I-03 — Audio/volumen

**Estado:** bloqueado.  
PipeWire entra en bucle `ENOSYS` bajo proot; puede consumir CPU. La sesión no arranca audio salvo `RT_ENABLE_AUDIO=1` (no recomendado). No hay slider de volumen.

Futuro:

- PulseAudio en modo usuario con socket.
- PipeWire con `--no-rt` y módulos mínimos.
- Un puente Android audio (difícil sin root).
- Aceptar que el audio no es parte del MVP.

### I-04 — Bluetooth

**Estado:** bloqueado.  
No hay adaptador BlueZ ni `/dev/rfkill`; el tile no aparece.

Futuro:

- Compartir un adaptador USB/Android (no disponible).
- Simulación solo cosmética; no recomendable.

### I-05 — Brillo/batería

**Estado:** bloqueado.  
El proot no expone backlight ni batería del S25. No hay slider real.

Futuro:

- Leer Battery/backlight vía Termux:API + puente D-Bus.
- Stub solo si se acepta que no controla hardware.

### I-06 — Wi-Fi simulado y chevron

**Estado:** parcial.  
`nm-stub.py` muestra `SubstrateOS` y el tile Wi-Fi; el chevron del submenú no abre en MacTahoe.

Futuro:

- Corregir el popup del submenú en el tema.
- Conectar NetworkManager real si se puede compartir la red Android.

### I-07 — Root/dock y apps

**Estado:** parcial.  
El shell es root; apps del dock heredan root. Algunas apps (Nautilus en ciertos flujos) pueden rechazar root o comportarse distinto.

Futuro:

- Sesión como `dexuser` o wrapper de lanzamiento por app.
- `.desktop` con `substrate-gpu-run` para apps 3D.

### I-08 — Rendimiento del compositor software

**Estado:** aceptado como tradeoff.  
El escritorio estable usa CPU para componer 2000x1200. Puede notarse en animaciones y arrastre de ventanas.

Futuro:

- Recuperar compositor hardware (I-01).
- Reducir resolución/escala.
- Benchmark formal de FPS/CPU.
- Optimizar servicios y RAM.

### I-09 — Snap/Flatpak

**Estado:** no recomendado.  
proot no ofrece el entorno de namespaces/systemd que esperan. Preferir `.deb`/AppImage.

### I-10 — Apps que requieren systemd/logind real

**Estado:** limitado.  
Solo se simula lo mínimo. Apps que llamen a `systemctl` o logind avanzado pueden fallar.

---

## 2. Cosas que ya se descartaron

- **Perfetto/perf/simpleperf para señales:** sin root no hay `signal_generate`; el trace no sirve.
- **Phantom process killer como causa primaria:** monitor desactivado, máximos enormes; el fallo coincide con GTK4/GPU.
- **OOM/LMKD:** no aparece `am_kill`/`lmkd` relevante; el patrón es GPU.
- **Cerrar con `wmctrl` como causa:** el shell muere antes o alrededor del cierre; no es la causa.
- **D-Bus/portal como única causa:** se probó app sin bus y también murió.
- **CSD visible con `GTK_CSD=0`:** GTK4 lo ignora; no cambió el resultado.
- **Sombras CSS:** quitarlas no evitó el fallo.
- **Software selectivo:** el compositor software es la única configuración determinista encontrada.

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

- Compositor hardware (`kgsl_fds=4`).
- Abrir/cerrar Text Editor, Calculator y Widget Factory 10 veces.
- 10 minutos de idle con ventana GTK4 abierta.
- Sin `SHELL_EXIT=137`.
- Captura con color y sombras/animaciones.
- Apps GPU siguen usando Adreno.
- Sin regresiones en dock/tema.

Hasta entonces, **software es el modo soportado**.

---

## 5. Riesgos

- Cambiar el compositor a hardware puede volver a matar el shell; no hacerlo sin backup.
- Cambiar usuario del shell puede romper buses/portales.
- Instalar apps que arrastren systemd/snap puede añadir ruido.
- Borrar `/tmp/rt-dex` sin respaldo rompe la restauración.
- Usar `pkill -f` puede tumbar la sesión SSH/OpenCode.
- Forzar `FD_MESA_DEBUG` sin probar puede ocultar o mover el fallo.
