# Ingesta de artículos Dexerto a Google Drive

## Flujo

El workflow **Dexerto — ingesta a Drive** obtiene URLs recientes de los sitemaps de Dexerto, filtra rutas de gaming de los últimos siete días, descarga cada página y guarda un Google Doc en `Gaming-News`.

El cuerpo se obtiene primero de `articleBody` en el JSON-LD de la página. Si no está disponible, el flujo intenta extraer el texto de `#article-content`. Los resultados con menos de 200 caracteres se descartan para no crear documentos vacíos.

## Prueba segura

1. Abra el workflow y refresque el navegador si no ve los nodos nuevos.
2. Seleccione **Extraer contenido del artículo** y use **Execute step** con datos de entrada de una ejecución previa, o ejecute el flujo manualmente.
3. Revise que su salida tenga `articleText` y que el texto sea legible.
4. Solo después ejecute la ruta completa hacia **Guardar artículo en Google Drive**.

## Operación

- **Probar backfill manual** consulta el mes actual y el anterior, pero el filtro conserva únicamente los últimos siete días.
- **Revisar novedades cada 15 min** usa el sitemap de noticias reciente.
- La primera ejecución puede crear varios Google Docs. Desactive la conexión al nodo de Drive para inspeccionar salidas sin escribir archivos.

## Retención de publicaciones

El workflow **05 — Dexerto — purgar publicaciones tras 72 h (Google Drive histórico)** se ejecuta cada día a las 00:10 en la zona horaria configurada para n8n. Usa la fecha inicial del nombre del archivo (`YYYY-MM-DD-`) como fecha de publicación y mueve a la papelera, sin eliminarlos permanentemente, los archivos publicados antes del inicio del día de hace tres días.

Ejemplo: el 15 de octubre, conserva los documentos del 12, 13, 14 y 15; envía a la papelera los del 11 o anteriores. Los nombres que no empiezan por una fecha válida se omiten.

## Límites actuales

- Aún no hay deduplicación persistente por URL: activar el monitor puede repetir archivos ya guardados.
- La extracción de vídeos embebidos no forma parte de este flujo todavía.
