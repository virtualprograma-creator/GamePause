# SteamDiscord GameMode

Modo juego para Windows con interfaz sencilla en PowerShell. Permite cerrar aplicaciones opcionales antes de jugar, manteniendo Steam y Discord fuera de la lista de cierre.

## Uso

1. Descarga el repositorio con **Code > Download ZIP** y extrae los archivos.
2. Abre **Modo juego.cmd**.
3. Revisa las aplicaciones detectadas y selecciona las que quieres cerrar.
4. Pulsa **Cerrar seleccionadas**.

Requiere Windows 10/11 y Windows PowerShell 5.1 con interfaz de escritorio. No necesita instalaciones adicionales ni ejecutarse como administrador. El lanzador usa `ExecutionPolicy Bypass` solo para esa ejecución; no cambia la configuración persistente de PowerShell.

## Aplicaciones admitidas

WhatsApp, Enlace Móvil, Battle.net, Epic Games, EA, NVIDIA Overlay, Game Bar, sus widgets, Widgets de Windows, notificaciones Wondershare, sincronizador Adobe Acrobat, Chrome y Codex/ChatGPT. Solo aparecen las aplicaciones detectadas con nombre y ruta compatibles.

Chrome, Codex, Adobe y las herramientas de grabación vienen desmarcados.

## Cierre normal y forzado

Por defecto se solicita el cierre normal. Una aplicación puede pedir guardar trabajo o permanecer abierta. Las aplicaciones sin ventana deben cerrarse desde su icono en la bandeja.

La casilla **Forzar cierre de apps opcionales** permite finalizar únicamente las aplicaciones seleccionadas de esta lista:

- WhatsApp y Enlace Móvil.
- NVIDIA Overlay, Game Bar y Xbox Game Bar Widgets.
- Widgets y WidgetService de Windows.
- Notificaciones Wondershare y AdobeCollabSync.

Chrome, Codex y lanzadores externos siempre usan cierre normal. Guarda tu trabajo y evita cerrar aplicaciones con llamadas, grabaciones o sincronizaciones en curso. El cierre forzado puede perder actividad pendiente.

## Límites y protecciones

- Lista permitida por nombre y ruta; no decide qué cerrar por consumo de RAM.
- Revalida el momento de inicio para evitar actuar sobre un PID reutilizado.
- El cierre forzado se limita a la sesión actual.
- No detiene servicios ni modifica el inicio de Windows.
- Steam, Discord, juegos, antivirus, VPN y controladores no están en la lista.
- Los registros locales se guardan en `Registros/` y no se publican con Git.
- No restaura automáticamente las aplicaciones ni garantiza una mejora en FPS.
- Nombre y ruta no sustituyen una comprobación criptográfica del ejecutable.

La interfaz se probó en Windows 11. La compatibilidad declarada con Windows 10 no se verificó en un equipo separado. Las pruebas de protección no finalizan aplicaciones reales.

## Comprobar sin cerrar aplicaciones

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\ModoJuego.ps1 -PreviewOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Protecciones.ps1
```

## Desarrollo

La interfaz y las opciones están en `ModoJuego.ps1`; las listas permitidas están en `Seguridad.ps1`. Para ampliar la lista, identifica primero el ejecutable y su ruta, evita agregar servicios y añade pruebas de protección.
