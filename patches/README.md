# Parches y modificaciones externas

## Ubuntu Dock: evitar autostart de Nautilus

Archivo real:

```
/usr/share/gnome-shell/extensions/ubuntu-dock@ubuntu.com/fileManager1API.js
```

Cambio aplicado en la creación del `Gio.DBusProxy`:

```diff
-            }, this._cancellable);
+            }, this._cancellable, Gio.DBusProxyFlags.DO_NOT_AUTO_START);
```

Contexto alrededor de la línea 45:

```js
this._proxy = new FileManager1API(...);
// ...
}, this._cancellable, Gio.DBusProxyFlags.DO_NOT_AUTO_START);
```

Efecto: el dock no inicia automáticamente el servicio de gestor de archivos al arrancar; el escritorio queda limpio. La app Files puede abrirse manualmente.

## Extensiones

- `ding@rastersoft.com` desactivada.
- `snapd-prompting@canonical.com` desactivada.
- `user-theme@gnome-shell-extensions.gcampax.github.com` activa.
- `ubuntu-dock@ubuntu.com` activo.
- `appindicators` y `tiling-assistant` conservados.

## Tema

MacTahoe no se parchea dentro de GNOME; se instala como tema/iconos y se selecciona por gsettings. Los assets no se incluyen completos en este repo por tamaño; ver `docs/02-INSTALACION-LIMPIA.md`.

## Fake logind

`/usr/local/share/substrate/fake-login1.py` implementa el mínimo de `org.freedesktop.login1`. No sustituye a systemd.

## Red

`/usr/local/share/substrate/nm-stub.py` implementa un NetworkManager simulado para que GNOME muestre el tile Wi-Fi. No controla la red real de Android.
