# Evidencia

Capturas reales de la máquina. No son renders ni maquetas.

## Instantánea 2026-11-17 (compositor Zink/Turnip)

| Archivo | Qué muestra |
|---|---|
| `06-desktop-software-antes.png` | Escritorio con compositor **software** (llvmpipe/swrast), línea base. 90 268 colores. |
| `07-desktop-zink-despues.png` | Escritorio con compositor **Zink/Turnip**. 93 315 colores. |
| `08-mactahoe-zink.png` | Tema MacTahoe-Dark sobre Zink (`kgsl_fds=1`). 94 137 colores. |
| `09-blender-zink.png` | Blender 5.0.1 abierto vía `substrate-gpu-run` sobre Zink. 94 847 colores. |
| `10-bench-delta.txt` | `glxgears` + RSS + colores antes/después. |
| `11-logcat-phantom-kill.txt` | Extracto de logcat: Android matando el árbol de la sesión durante el stress inicial (pico de procesos at-spi/ibus). |
| `12-idle-gtk4-10min.png` | Text Editor GTK4 abierto durante 10 min sin morir (87 145 colores). |
| `13-arranque-frio-zink.png` | Arranque en frío `gnome49-stop` + `gnome49` con los scripts finales (92 762 colores). |
| `14-boot-series.csv` | Serie cruda de **15 arranques en frío** instrumentados (2 SIGKILL = 13.3%, al pintar la UI inicial). |
| `15-watcher-muerte-boot8.txt` | Forense cruda de una muerte: watcher kgsl 1 Hz, estados, memoria, GPU busy, y eliminación de sospechosos. |
| `16-visibilidad-rmse.txt` | Gate RMSE ventana-vs-pantalla: invisible antes del fix, **RMSE=0/AE=0** después. Demuestra el falso positivo del conteo de colores. |
| `17-app-invisible-antes.png` | Calculadora "abierta" e invisible (Zink sin `COGL_DISABLE_TFP`): la región muestra el wallpaper. |
| `18-app-visible-despues.png` | `xlogo` compuesto pixel-exacto tras el fix (`COGL_DISABLE_TFP=1`). |

## Instantánea 2026-11-16 (compositor software)

| Archivo | Qué muestra |
|---|---|
| `01-editor-dark-software-shell.png` | Text Editor GTK4 oscuro, traffic lights, dock flotante, wallpaper MacTahoe day, shell software. |
| `02-escritorio-limpio.png` | Escritorio limpio sin ventanas de prueba. |
| `03-widgetfactory-hardware-nolrz.png` | Widget Factory GTK4 con compositor hardware + `FD_MESA_DEBUG=nolrz` (modo experimental). |
| `04-editor-software.png` | Text Editor GTK4 en la primera prueba estable con compositor software. |
| `05-calculator-software.png` | Calculator GTK4 con compositor software. |
| `05-mactahoe-zink.png` | Primera captura MacTahoe ya con Zink (2026-11-17). |

## Criterio de color

- Compositor software: ~90 268 colores.
- Compositor Zink: 93 315–94 847 colores.
- En ambos casos >90 000 indica UI real pintada (no pantalla negra).

Las capturas se tomaron con:

```bash
DISPLAY=:0 scrot -o /tmp/rt-dex/archivo.png
```

No se incluyen logcat completos (decenas de MB); se guarda un extracto con la
evidencia del kill. Los logs completos viven en `/tmp/rt-dex/`.
