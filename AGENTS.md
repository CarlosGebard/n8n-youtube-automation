# Operación de n8n: Honi YouTube Automation

## Fuente de verdad

La instancia n8n visible en la UI es la fuente de verdad de workflows, ejecuciones y credenciales. Los JSON de `workflows/` son snapshots versionados: no asumir que reflejan la UI sin comprobarlo.

Antes de diagnosticar, editar o ejecutar un workflow:

1. Consultar el workflow vivo mediante el MCP `n8n`.
2. Usar su ID y nombre reales, no sólo el nombre de un archivo JSON.
3. Tras un cambio aprobado, actualizar el snapshot del repositorio y comprobar que coincide con la UI.

No escribir directamente en PostgreSQL de n8n. La API REST es sólo un respaldo de lectura cuando MCP no esté disponible.

## Conexión MCP integrada

n8n incluye su propio servidor MCP; no instalar un servidor MCP externo.

- Servidor global de Codex: `n8n`
- URL: `http://localhost:5678/mcp-server/http`
- Autenticación: bearer token en `N8N_MCP_TOKEN`
- El token se guarda únicamente en `.env`, que está ignorado por Git. Nunca copiarlo a `AGENTS.md`, JSON, commits, comandos visibles ni mensajes.

Para abrir una sesión nueva de Codex con el token disponible:

```sh
set -a
source ./.env
set +a
codex
```

Verificar el registro local con:

```sh
codex mcp list
```

En n8n, habilitar **Settings → Instance-level MCP** y exponer sólo los workflows canónicos de abajo. Dar a Codex permiso de lectura, actualización y ejecución únicamente mientras sea necesario.

## Procedimiento operativo obligatorio

1. `get_workflow_details` para leer el workflow vivo y su versión actual.
2. Para una modificación, usar `update_workflow` con operaciones parciales y atómicas; no reemplazar el grafo entero.
3. Para probar lógica sin servicios externos, usar `test_workflow` con datos fijados.
4. Para una prueba real autorizada, usar `execute_workflow` en modo `manual`, indicando el trigger cuando haya más de uno.
5. Consultar `get_workflow_execution` hasta el estado final y reportar: estado, nodo final, conteos y error concreto si existe.
6. Actualizar el JSON correspondiente en `workflows/` y comparar su contenido relevante con la UI.

No pedir al usuario que ejecute manualmente un workflow si MCP está conectado y el usuario ya autorizó la prueba.

## Workflows canónicos

| Nº | ID de UI | Nombre | Responsabilidad |
| --- | --- | --- | --- |
| 01 | `PvcuN0zryjedVsbn` | `01 — Dexerto — ingesta editorial` | Sitemap Dexerto → descarga y extracción → Nextcloud + artículo pendiente en PostgreSQL. |
| 02 | `Jabzoiy0VaCyAbxc` | `02 — Editorial — clasificar artículos entrantes` | Ejecuta el Prompt 1 y guarda historial inmutable; `Queue` queda para agrupación posterior. |
| 03 | `RAsE71PzfTGz1nxf` | `03 — Editorial — agrupar Queue Daily News` | Ejecuta el Prompt 2 y crea colas Daily News desde artículos `Queue`. |
| 04 | `zGsUUkJ8vONVTclX` | `04 — Editorial — crear guiones` | Ejecuta el Prompt 3 para un `Individual` (`SINGLE_NEWS`) o una cola Daily News (`DAILY_ROUNDUP`), y guarda el JSON en Nextcloud. |
| 05 | `mZ1aDnHvsCgmCHr9` | `05 — Google Drive → Vast Fish TTS` | Convierte guiones de Google Drive a audio mediante Vast Fish TTS. |
| Extra | `mCGE962bpcmEJNRO` | `Extra — Editorial — exportar catálogo XLSX` | Exporta el catálogo transversal por etapa a XLSX en Nextcloud. |
| Extra | `zuP1HzZI7798YAsf` | `Extra — Dexerto — purgar publicaciones tras 72 h (Google Drive histórico)` | Retención histórica de Google Drive; no pertenece al pipeline editorial nuevo. |

## Contrato editorial por etapas

- `pending` es un estado técnico de `article_classification_jobs`; no es una decisión editorial.
- El Prompt 1 clasifica cada artículo como `Individual`, `Queue` o `Discard` y conserva la respuesta en `article_classifications`.
- Sólo `Queue` pasa al Prompt 2 de agrupación y priorización en Daily News.
- `Individual` crea un trabajo de guión `SINGLE_NEWS`; una cola Daily News agrupada crea un trabajo `DAILY_ROUNDUP`. Ambos usan el Prompt 3 y conservan tablas y artefactos separados.
- `articles` conserva identidad y procedencia. No volver a añadir resultados de prompts ni estados de producción a esa tabla.

## Workflows legacy actualmente presentes en la UI

No ejecutar, editar ni usar como base estos workflows. Fueron reintroducidos al restaurar el volumen histórico y deben mantenerse fuera del flujo operativo hasta su retirada explícita:

- `DdoiKg7dcVXuxpgx` — `Dexerto — pipeline editorial (Dexerto → Nextcloud → LiteLLM)`
- `swxdW3yv4B44B7wd` — `Editorial — clasificar artículos pendientes`
- `RDIMkxwG34gHtlc4` — `Editorial — exportar catálogo XLSX`
- `6wdRPYtVZIjFPOvf` — `Google Drive → Vast Fish TTS`
- `h2RbiTEb8Pv1GMke` — `Kotaku Games — enlaces individuales`
- `zo9jrE137GM89IRm` — `Limpieza temporal — Dexerto sin contenido`
- `cmzRrmQLOk87BD3D` — `Dexerto — purgar publicaciones tras 72 h`

Antes de borrar un workflow legacy, confirmar su ID en la UI y la autorización expresa del usuario. Exportarlo como respaldo sólo si el usuario lo solicita.
