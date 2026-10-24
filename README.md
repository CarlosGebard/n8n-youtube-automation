# Honi YouTube Automation

Entorno local y snapshots operativos para el pipeline editorial de Honi: ingesta, clasificación, Daily News, voz y vídeo.

## Estructura

- `assets/`: recursos locales no generados. La referencia vocal está en `assets/audio/voice-references/` y debe mantenerse privada.
- `data/`: datos editoriales locales. `editorial/exports/` contiene exportaciones XLSX; `editorial/reference/` conserva archivos de referencia.
- `prompts/`: contratos de prompt versionados para clasificación, agrupación `Queue` y guión Daily News. Se montan de sólo lectura en n8n.
- `workflows/`: snapshots de los workflows editoriales canónicos. La instancia de n8n es la fuente de verdad; consulte primero el workflow vivo antes de modificar un snapshot.
- `docs/`: ADRs y runbooks de operación.
- `ops/`: esquema SQL y scripts auxiliares.
- `n8n-youtube-automation/`: repositorio Git independiente del worker Fish Audio/Vast y su snapshot de workflow TTS.

## Inicio local

Revise [el runbook de n8n](docs/runbooks/n8n-local.md). La pila se inicia desde esta raíz con `docker compose up -d`.

Tras cambiar `compose.yml` o la ubicación de un archivo montado, aplique el cambio con:

```sh
docker compose up -d --force-recreate n8n
```

## Datos y respaldo

Los contenidos de `assets/` y `data/` son locales y se conservan fuera de los flujos de despliegue. Inclúyalos en un respaldo privado; no copie referencias vocales, credenciales ni archivos de datos a repositorios públicos.

## Pipeline editorial

PostgreSQL es la fuente de verdad y Nextcloud conserva los artefactos. La ruta
operativa es `artículo → clasificación → (Individual → guión SINGLE_NEWS | Queue
agrupada → guión Daily News) → voz → vídeo`. Ambos formatos usan el mismo
Prompt 3 y conservan sus trabajos, tablas y artefactos por separado; `Discard`
no avanza. Revise el
[runbook editorial](docs/runbooks/editorial-pipeline.md) antes de activar un
workflow.

Durante el ajuste de prompts, las clasificaciones se reevalúan sin borrar el
catálogo mediante `ops/scripts/requeue-classification.sh`; el procedimiento
está en el runbook editorial.
