# ADR 0002: Ingesta de Kotaku preparada para Google Drive

## Estado

Aceptado para pruebas iniciales.

## Contexto

Se requiere recopilar artículos de la categoría Games de Kotaku, cargar inicialmente los últimos siete días y vigilar artículos nuevos. Los documentos resultantes se usarán más adelante como insumo para una revisión editorial y guiones.

## Decisión

El workflow tendrá dos entradas: una manual que solicita páginas del RSS para la carga inicial, y una programada cada quince minutos que consulta solo la primera página. Ambos caminos normalizan el campo RSS `link` como URL canónica y filtran artículos de los últimos siete días.

El workflow se importa inactivo. El nodo de Google Drive permanece deshabilitado y no contiene credenciales, secreto OAuth ni identificador de carpeta. El usuario conectará su propia credencial desde n8n antes de habilitarlo.

## Consecuencias

- La carga inicial y el monitoreo quedan visualmente separados en el mismo workflow.
- Es posible probar la obtención y transformación de datos sin escribir en Drive.
- Antes de activar el monitoreo se debe añadir deduplicación durable, preferiblemente con PostgreSQL usando `article_url` como clave única.
