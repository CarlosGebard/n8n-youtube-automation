# ADR 0005: estado editorial por etapa y Daily News para Queue

## Estado

Aceptado.

## Contexto

El diseño inicial concentraba en `articles` la fuente, el almacenamiento, el
estado de clasificación y la última decisión del LLM. Eso mezclaba contratos de
etapas distintas y hacía que `Queue` se confundiera con un estado técnico
pendiente.

## Decisión

`articles` conserva la identidad y procedencia. `article_contents` es dueño de
los objetos de Nextcloud. `article_classification_jobs` controla reintentos y
bloqueos, mientras `article_classifications` conserva respuestas inmutables del
Prompt 1.

Una decisión `Queue` se agrupa mediante el Prompt 2 en `daily_news_queues` y
`daily_news_queue_articles`. Sólo una cola agrupada puede alimentar el Prompt 3
y crear un registro en `daily_news_scripts`. Voz y vídeo tienen sus propios
trabajos y no alteran el historial editorial.

`Individual` no entra a Daily News; crea su propio trabajo de guión
`SINGLE_NEWS`, según ADR 0006. `Discard` termina su recorrido editorial.

## Consecuencias

- Las columnas heredadas de estado en `articles` quedan sin escritura nueva
  durante la transición; no se eliminan hasta una migración de retirada
  autorizada.
- El XLSX es una vista de auditoría transversal, no una cola ni fuente de
  verdad.
- Los workflows de prompts permanecen inactivos hasta una prueba manual
  autorizada con las credenciales reales.
