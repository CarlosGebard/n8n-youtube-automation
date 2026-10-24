# ADR 0004: estado editorial en PostgreSQL y contenido en Nextcloud

## Estado

Aceptado.

## Contexto

El flujo editorial de Dexerto usaba documentos de Google Drive y una hoja de cálculo como estado. Se necesita clasificar artículos de forma reproducible con `agent_categorizer.md`, conservar el contenido extraído y permitir reintentos sin volver a descargarlo.

## Decisión

Se crea la base `editorial`, separada de la base interna `n8n`, como fuente de verdad relacional. Nextcloud guarda dos objetos inmutables por artículo: `article.md` con el texto normalizado y `source.json` con sus metadatos. PostgreSQL conserva la URL canónica, rutas de Nextcloud, huella de contenido, estados de carga y clasificación, decisiones, ejecuciones e historial de respuestas del LLM.

La clasificación sólo puede reclamar artículos cuyo contenido esté confirmado como `stored`. La exportación XLSX a Nextcloud es una vista de auditoría compatible conceptualmente con `Editorial-Database.xlsx`; no es una fuente de estado ni un mecanismo de bloqueo.

## Consecuencias

- Un fallo de Nextcloud deja el artículo en `pending_upload` o `failed`, sin enviarlo al LLM.
- Un fallo de LiteLLM conserva el contenido y permite reintentar la clasificación.
- Los documentos existentes en Google Drive no se modifican ni eliminan durante la migración.
- Las credenciales de Nextcloud, PostgreSQL y LiteLLM se crean en n8n y no se guardan en JSON, SQL ni `.env.example`.
