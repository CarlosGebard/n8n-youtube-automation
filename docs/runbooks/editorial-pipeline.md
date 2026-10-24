# Runbook: pipeline editorial Honi

## Estado y almacenamiento

La base `editorial` mantiene el estado del pipeline. No se debe escribir en las tablas internas de la base `n8n`.

Cada etapa es dueña de su estado:

1. `articles` y `article_contents`: fuente y objetos Markdown/JSON.
2. `article_classification_jobs` y `article_classifications`: trabajo e historial del Prompt 1.
3. `daily_news_queues` y `daily_news_queue_articles`: agrupación de `Queue` por el Prompt 2.
4. `individual_script_jobs` y `individual_scripts`: trabajo y resultado de
   `SINGLE_NEWS` para una decisión `Individual`.
5. `daily_news_script_jobs` y `daily_news_scripts`: trabajo y resultado de
   `DAILY_ROUNDUP` para una cola agrupada.
6. `voice_jobs` y `video_jobs`: producción posterior. `voice_jobs` admite una
   fuente `daily_news` o `individual`, nunca ambas, y no se deben avanzar sin
   una aprobación de prueba real.

## Editar el prompt del clasificador

El contrato editable vive en `prompts/editorial/agent_categorizer.md`. El workflow 02 mantiene una copia sincronizada dentro del nodo `Preparar entrada segura`, porque esta instancia de n8n bloquea la lectura de archivos locales durante la ejecución.

Para cambiarlo, edita ese archivo versionado y sincroniza solamente el parámetro `jsCode` del nodo en el workflow vivo; luego ejecuta una prueba manual. No edites la copia embebida directamente desde la UI: se perdería al siguiente sync.

## Iterar el clasificador en desarrollo

No borres artículos, archivos de Nextcloud ni clasificaciones anteriores. Cada resultado se conserva como historial inmutable. Tras editar el prompt, vuelve a poner en cola el conjunto que quieras reevaluar:

```sh
# Un artículo concreto
sh ops/scripts/requeue-classification.sh --article-id 42

# Todo el catálogo de desarrollo
sh ops/scripts/requeue-classification.sh --all
```

El comando sólo restablece el trabajo a `pending`; no borra datos. La siguiente ejecución manual del workflow 02 reclama un artículo y guarda una nueva clasificación. Úsalo con el workflow 02 inactivo para evitar que el Schedule Trigger procese más artículos de los previstos.

## Probar un artículo sin escribir en la base editorial

Para recorrer Nextcloud, el prompt, LiteLLM y la validación sin reclamar,
insertar ni actualizar filas editoriales:

```sh
sh ops/scripts/dry-run-classifier.sh --article-id 1
```

El comando fija los nodos PostgreSQL de reclamo, historial y actualización.
Sólo realiza lecturas de PostgreSQL y Nextcloud, e invoca LiteLLM. n8n puede
conservar el registro técnico de la prueba, pero la base `editorial` no cambia.

Nextcloud mantiene el contenido asociado a cada artículo:

```text
/n8n-youtube-automation/Honi-News/Dexerto-Articles/YYYY-MM-DD-<article-slug>.md
/n8n-youtube-automation/Honi-News/Dexerto-Articles/YYYY-MM-DD-<article-slug>.json
/n8n-youtube-automation/Honi-News/Dexerto-Exports/Editorial-Articles-latest.xlsx
/n8n-youtube-automation/Honi-News/Daily-News/Scripts/queue-<queue-id>-<execution-id>.md
/n8n-youtube-automation/Honi-News/Individual-News/Scripts/article-<article-id>-<execution-id>.md
/n8n-youtube-automation/Honi-News/Audio/<script-id>-<execution-id>.wav
```

Los archivos Markdown son para lectura y revisión editorial. Cada ejecución
crea una versión nueva para no depender de sobrescribir un archivo bloqueado
por WebDAV. PostgreSQL es la
fuente de verdad: `script_text` permite búsqueda y el `raw_response` JSONB
conserva etiquetas Fish, avatar, visuales y captions. El XLSX es una
exportación de revisión que incluye contenido, clasificación, cola, guión, voz
y vídeo cuando existan. El
workflow 03 dispone de un Schedule Trigger horario, pero permanece inactivo
hasta validar una exportación manual.

## Inicializar la base editorial

Desde la raíz del repositorio:

```sh
sh ops/scripts/init-editorial-db.sh
```

El script crea la base `editorial` si falta y aplica el esquema de forma idempotente. No modifica datos de la base `n8n`.

## Credenciales requeridas en n8n

Antes de activar workflows, cree estas credenciales sin incluir secretos en los exports:

1. **Postgres Editorial**: host `postgres`, puerto `5432`, base `editorial`, usuario `n8n`, contraseña igual a `POSTGRES_PASSWORD`, SSL desactivado.
2. **Nextcloud Editorial**: tipo **NextCloud API**, con URL WebDAV `<URL_NEXTCLOUD>/remote.php/webdav`, usuario y contraseña de aplicación.
3. **LiteLLM Editorial**: tipo **OpenAI**, URL base `https://raspberry-media-server.tail116b62.ts.net:8448/v1` y una clave de LiteLLM. La URL termina en `/v1`, no en `/v1/chat/completions`. Los prompts versionados pueden reutilizar esta credencial; no use claves Gemini dentro de n8n.
4. **Vast Fish Adapter Auth**: tipo **Header Auth**, con el bearer token del
   adaptador. Defina además `VAST_FISH_ADAPTER` en `.env` como su URL base;
   el workflow añade `/v1/generate`. No guarde el token, la referencia vocal o
   credenciales Vast en exports de workflows.

## Preparación de Nextcloud

Cree de forma manual las carpetas `n8n-youtube-automation/Honi-News/Dexerto-Articles` y `n8n-youtube-automation/Honi-News/Dexerto-Exports` antes de la primera ejecución. El usuario de la credencial debe poder crear y sobrescribir archivos dentro de ellas.

## Orden de primera ejecución

1. Ejecute manualmente **01 — Dexerto — ingesta editorial**. Guarda el contenido y crea un trabajo de clasificación.
2. Ejecute **02 — Editorial — clasificar artículos entrantes**. Sólo clasifica; registra un historial inmutable y deja `Queue` listo para agrupación.
3. Una decisión `Individual` queda lista directamente para **04 — Editorial — crear guiones**, que generará un paquete `SINGLE_NEWS`.
4. Ejecute la etapa de agrupación `Queue` para crear colas `DAILY_ROUNDUP`.
5. Ejecute **04 — Editorial — crear guiones**. Reclama una sola unidad elegible —Individual o Daily News— y guarda el JSON en su carpeta de Nextcloud.
6. Tras aprobar Creative y dejar Production en `ready`, ejecute manualmente
   **05 — Production Plan → Vast Fish Audio**. Compruebe que `voice_jobs`
   termina `completed`, que `audio_uri` existe en Nextcloud y que el script
   queda `voiced`. No se debe reintentar un estado `processing` sin investigar
   primero el error.
7. Ejecute **Extra — Editorial — exportar catálogo XLSX** y compruebe `Editorial-Articles-latest.xlsx` en Nextcloud. Active su schedule horario sólo después de esa validación.

No active schedules ni producción de voz/vídeo hasta validar manualmente cada
etapa con datos reales autorizados.

La separación permite reintentar clasificación o exportación sin volver a descargar artículos.

## Seguridad editorial

- El texto de los artículos es entrada no confiable y no puede alterar las instrucciones del clasificador.
- El clasificador sólo reclama trabajos cuyo contenido tenga estado `stored`.
- `Queue` no significa “pendiente”: es una decisión editorial que pasa al prompt de agrupación y luego al guión Daily News. `Individual` evita esa agrupación y entra directamente al mismo Prompt 3 como `SINGLE_NEWS`.
- Los prompts viven en `agent_categorizer.md`, `agent_queue_grouper.md` y `agent_daily_news_writer.md`; el montaje de Compose los deja disponibles tras recrear n8n.
- `N8N_RESTRICT_FILE_ACCESS_TO` limita el nodo de lectura a `/home/node/.n8n`, donde viven los prompts montados. No amplíe esa lista sin una necesidad revisada.
- No active el Schedule Trigger hasta validar una ejecución manual de cada etapa.
