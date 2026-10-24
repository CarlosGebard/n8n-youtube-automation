# Flujo Kotaku Games: enlaces individuales

El endpoint `https://kotaku.com/games/feed` es un feed RSS 2.0, no una API JSON. En cada elemento RSS, el campo `link` contiene la URL pública y canónica del artículo individual. Use ese campo; `guid` es un identificador interno y no el enlace editorial recomendado.

El flujo `Kotaku Games — enlaces individuales` ejecuta tres pasos:

1. Inicio manual para pruebas.
2. Lectura del feed con **RSS Feed Read**.
3. Normalización a `articleUrl`, `title`, `publishedAt` y `summary`.

Para probarlo, abra el flujo en n8n y seleccione **Execute workflow**. La salida de `Conservar URL y metadatos` contiene un ítem por artículo. `articleUrl` se puede conectar después a un nodo HTTP Request, un extractor HTML o un proceso de persistencia.

El flujo se mantiene inactivo para evitar ejecuciones automáticas. Cuando la extracción esté validada, sustituya el disparador manual por Schedule Trigger y defina la frecuencia deseada.
