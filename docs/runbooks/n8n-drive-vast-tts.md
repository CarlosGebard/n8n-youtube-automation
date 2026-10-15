# Configurar n8n: Google Drive a Vast Fish TTS

Importa `workflows/drive-script-to-vast-tts.json`. El workflow queda inactivo y sólo se inicia manualmente.

## Preparación de Drive

1. Crea dos carpetas: una para los guiones de entrada y otra para los audios.
2. Añade inicialmente archivos `.txt` o `.md` de un máximo de 5.000 caracteres. Los Google Docs se incorporarán en una iteración posterior con exportación explícita a texto.
3. Inserta los IDs de ambas carpetas en los nodos de Drive. El ID es el último componente de la URL de una carpeta.
4. Conecta una credencial OAuth de Google Drive sólo a los nodos **Buscar guiones en Drive**, **Descargar guion** y **Guardar audio en Drive**.

Para reducir alcance, usa una cuenta Google dedicada a la automatización y comparte exclusivamente estas dos carpetas con ella. No conectes una cuenta con acceso a todo el Drive personal si no es necesario.

## Credencial de Vast en n8n

1. Crea una credencial **Header Auth** en n8n.
2. Nombre del header: `Authorization`.
3. Valor: `Bearer TU_VAST_API_KEY`.
4. Asóciala únicamente al nodo **Generar voz en Vast**. No pongas el token en el JSON del workflow, campos Set, notas ni expresiones.

Cuando exista el endpoint, sustituye `REPLACE_WITH_ENDPOINT_ID` en la URL del nodo. El workflow usa un timeout de 15 minutos para admitir el arranque en frío sin multiplicar solicitudes.

## Primera prueba

1. Conserva deshabilitado el nodo **Guardar audio en Drive**.
2. Ejecuta manualmente un único `.txt` corto y revisa que el nodo Vast recibe audio binario en el campo `audio`.
3. Escucha el WAV descargado desde la ejecución.
4. Habilita la subida y repite la prueba. Sólo después considera un trigger programado y deduplicación persistente.

## Restricciones actuales

- No procesa Google Docs directamente: evita errores de exportación silenciosos en la primera versión.
- Un archivo se convierte en un WAV; los guiones de más de 5.000 caracteres fallan de forma visible en vez de truncarse.
- El workflow no tiene deduplicación todavía. No lo actives con un Schedule Trigger hasta guardar `sourceFileId + scriptHash` en PostgreSQL o un Data Table de n8n.
