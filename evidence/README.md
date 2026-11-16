# Evidencia

Capturas reales de la máquina en la instantánea del 2026-11-16. No son renders ni maquetas.

| Archivo | Qué muestra |
|---|---|
| `01-editor-dark-software-shell.png` | Text Editor GTK4 oscuro, traffic lights, dock flotante, wallpaper MacTahoe day, shell software. |
| `02-escritorio-limpio.png` | Escritorio limpio sin ventanas de prueba. |
| `03-widgetfactory-hardware-nolrz.png` | Widget Factory GTK4 con compositor hardware + `FD_MESA_DEBUG=nolrz` (modo experimental). |
| `04-editor-software.png` | Text Editor GTK4 en la primera prueba estable con compositor software. |
| `05-calculator-software.png` | Calculator GTK4 con compositor software. |

Criterio de color: >100.000 colores únicos. La captura final midió **145.651**.

Las capturas se tomaron con:

```bash
DISPLAY=:0 scrot -o /tmp/rt-dex/archivo.png
```

No se incluyen logs completos para no exponer rutas/estado efímero; los logs viven en `/tmp/rt-dex/` y se describen en `docs/04-OPERACION-TESTS.md`.
