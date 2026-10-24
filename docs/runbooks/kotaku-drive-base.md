# Base de ingesta Kotaku a Google Drive

El workflow **Kotaku — ingesta a Drive (base)** se importa desactivado y no incluye secretos. Tiene dos entradas:

- **Probar backfill manual** recorre las primeras 20 páginas del RSS y conserva solo los últimos siete días.
- **Revisar novedades cada 15 min** está listo para revisar la primera página cuando el workflow se active.

## Preparar Google Drive

1. Cree la carpeta `Kotaku/Artículos` en su Drive.
2. En n8n, abra el nodo **Guardar artículo en Google Drive**.
3. Seleccione su credencial **Google Drive OAuth2 API**.
4. En el campo **Parent Folder**, seleccione `Gaming-News`.
5. El nodo usa **Create from text** y convierte `documentBody` en un Google Doc; no requiere datos binarios.
6. Ejecute primero **Probar backfill manual** y revise la salida de **Preparar archivo para Drive**.

No active el workflow programado todavía. Antes hay que añadir deduplicación durable basada en `articleUrl`; de lo contrario, cada ejecución podría producir una copia nueva del mismo artículo.

## Validación esperada

La ejecución manual debe mostrar elementos con estos campos:

- `articleUrl`
- `publishedAt`
- `title`
- `fileName`
- `documentBody`

El nodo de Google Drive requiere la credencial y la carpeta de destino antes de ejecutar el backfill.
