# ADR 0006: guiones separados para Individual y Daily News

## Estado

Aceptado.

## Contexto

El Prompt 1 puede decidir `Individual` o `Queue`. El diseño anterior sólo
materializaba trabajos de guión para una cola `Daily News`, dejando los
artículos `Individual` clasificados pero sin una siguiente etapa ejecutable.

## Decisión

`Individual` crea un `individual_script_jobs` asociado al artículo y a su
última clasificación. El workflow de guión reclama atómicamente un trabajo
Individual o Daily News y construye, respectivamente, un paquete
`SINGLE_NEWS` o `DAILY_ROUNDUP` para el mismo Prompt 3.

Los guiones se guardan en tablas separadas (`individual_scripts` y
`daily_news_scripts`) y en carpetas separadas de Nextcloud. Esto preserva las
restricciones relacionales de una cola de varios artículos y evita que un
artículo Individual se presente artificialmente como Daily News.

El archivo de OpenCloud es Markdown de lectura: narración limpia y un
frontmatter editorial conciso (título, formato, estado, prompt, modelo y
fecha), sin IDs ni etiquetas técnicas. `raw_response` en PostgreSQL conserva
el JSON de producción: etiquetas Fish, avatar, visuales, énfasis y notas. No
se añade una base de objetos adicional.

## Consecuencias

- La clasificación pasa a crear trabajos de guión sólo para `Individual`;
  `Queue` mantiene el Prompt 2 obligatorio.
- Las futuras etapas de voz y vídeo deberán admitir ambos tipos de guión, pero
  no se modifican en esta decisión.
- Volver a clasificar un artículo como `Individual` reactiva su trabajo de
  guión, sin eliminar el historial de clasificación ni el guión anterior.
