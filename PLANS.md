# Plan de ejecución — Honi News

## Próximo: alineación temporal de audio y entrega a Remotion

### Goal

Generar una transcripción palabra a palabra en milisegundos para cada WAV
aprobado, persistirla junto al audio y dejarla disponible para el futuro
workflow de Remotion sin bloquear la producción de voz.

### Scope

- Crear una etapa posterior a la subida correcta del WAV de workflow 05.
- Usar el guion canónico ya conocido para alineación forzada, no volver a
  inventar ni editar la narración.
- Evaluar primero una API de transcripción con timestamps y mantener WhisperX
  como alternativa de mayor precisión/autohospedada.
- Persistir un JSON temporal versionado y el estado del job; no implementar
  vídeo ni captions todavía.

### Validation

- Un WAV de prueba produce palabras ordenadas con `start_ms` y `end_ms`.
- La concatenación normalizada coincide con el texto canónico o informa las
  discrepancias sin reemplazarlo silenciosamente.
- Un fallo de alineación deja un estado recuperable y no revierte una voz ya
  subida.

## Cambio inmediato: sincronizar Performance Director V3.1

### Goal

Usar el prompt versionado HONI — PERFORMANCE DIRECTOR V3.1 en workflow 04 y
proporcionar un comando explícito para sincronizar cambios locales futuros.

### Scope

- Reemplazar el prompt V1.0 embebido que todavía usa el nodo vivo.
- Adaptar la salida segments de V3.1 al Production Plan consumido por la
  revisión Discord y el resto del pipeline, sin cambiar la narración.
- Documentar la sincronización mediante MCP.
- Reiniciar solo el guion individual-1-451.md después de la actualización.

### Validation

- Comparar la huella del prompt local con el texto embebido en n8n.
- Probar el adaptador de segmentos, tags Fish y preservación exacta del guion.
- Confirmar los estados y artefactos del guion reiniciado.

## Cambio inmediato: activar guiones por evento editorial

### Goal

Iniciar workflow 04 con el trabajo de guión exacto cuando workflow 02 produzca
un `Individual` o workflow 03 cree una cola Daily News, sin polling.

### Scope

- Añadir disparadores Execute Workflow y llamadas asíncronas 02 → 04 y 03 → 04.
- Pasar `job_type` y `subject_id`; 04 reclama exclusivamente ese trabajo.
- Conservar el trigger manual de 04 como drenaje controlado de la cola que
  exista antes de activar esta integración.
- No cambiar prompts, decisiones editoriales ni el flujo de revisión Discord.

### Validation

- Probar el reclamo exacto y el reclamo manual sin identificador dentro de una
  transacción con rollback.
- Verificar que las conexiones nuevas no disparan 04 para `Queue` ni `Discard`.
- Sincronizar los tres snapshots con los workflows vivos.

## Cambio inmediato: clasificar la cola editorial completa

### Goal

Hacer que workflow 02 reclame y clasifique todos los trabajos editoriales
elegibles (`pending` y `retry`) en cada ejecución, sin el límite arbitrario de
25.

### Scope

- Cambiar la llamada existente a `claim_article_classification_jobs` para usar
  un límite SQL nulo, que PostgreSQL interpreta como sin límite.
- Mantener el reclamo atómico, `FOR UPDATE SKIP LOCKED`, los estados y la
  clasificación secuencial ya configurada.
- No cambiar el prompt editorial, las decisiones ni el esquema de base de
  datos.

### Validation

- Verificar que `LIMIT NULL` no limita filas en PostgreSQL.
- Comprobar el nodo vivo, su snapshot y una prueba de contrato.

## Cambio inmediato: revisión de interpretación y audio por Discord

### Goal

Entregar al editor el Markdown de narración que realmente consumirá Fish Audio,
con sus etiquetas expresivas aplicadas, y requerir una segunda aprobación de
Discord antes de entregar el WAV a la etapa de captions o vídeo.

### Scope

- Mantener `script_text` sin etiquetas como narración canónica.
- Sobrescribir el Markdown de revisión tras Production Director y adjuntarlo a
  Discord como archivo completo, sin el límite de 2.000 caracteres del mensaje.
- Hacer que 05 adjunte el WAV generado y espere una decisión independiente.
- No añadir todavía WhisperX ni estados nuevos de base de datos: el WAV queda
  correctamente almacenado tras su subida y la aprobación será el disparador
  de workflow 06 cuando exista.

### Validation

- El Markdown adjunto recompone exactamente el texto canónico al retirar tags.
- Discord recibe un `.md` y después los botones de revisión.
- Discord recibe el WAV sólo tras una subida exitosa a Nextcloud.

## Cambio inmediato: aprobación humana por Discord

### Goal

Detener workflow 04 después de persistir un Production Plan y requerir una
decisión humana explícita en Discord antes de iniciar workflow 05.

### Scope

- Usar la operación nativa Discord **Send and Wait** de n8n, con botones
  `Aprobar` y `Rechazar` en un canal privado `#honi-review`.
- Persistir la decisión en `approval_status` y `approved_at_utc` de los
  guiones existentes; no crear una segunda fuente de estado.
- Iniciar 05 sólo por la rama aprobada y conservar su disparador manual para
  diagnósticos.
- Preparar un workflow auxiliar, ejecutable una vez, para crear el canal.

### Assumptions

- La credencial **Discord Bot API** se configura sólo en n8n con el token del
  bot; no se guarda en `.env`, snapshots ni Git.
- El canal de revisión será privado y sólo tendrá al editor autorizado y al
  bot. La operación nativa entrega decisiones mediante enlaces firmados, no
  lee mensajes de texto arbitrarios.

### Steps

1. Actualizar los workflows vivos 04 y 05 con operaciones atómicas y añadir
   el flujo auxiliar de creación de canal.
2. Añadir variables no secretas para el servidor y canal de revisión, ADR,
   runbook y prueba de contrato.
3. Probar las ramas aprobada/rechazada con datos fijados; la prueba real queda
   pendiente de asociar la credencial Discord Bot y los IDs del servidor/canal.

### Validation

- La aprobación deja el guión en `approved` con timestamp y dispara 05.
- El rechazo deja el guión en `rejected` y no tiene conexión a 05.
- Los snapshots coinciden con los workflows vivos y el JSON es válido.

## Cambio inmediato: clasificación desde PostgreSQL

### Goal

Eliminar la descarga de Markdown desde Nextcloud en workflow 02. La ingesta
guardará el mismo Markdown en `article_contents`, y la clasificación lo
reclamará directamente desde PostgreSQL.

### Scope

- Añadir una columna aditiva para el Markdown editorial y devolverla desde el
  reclamo de clasificación.
- Actualizar los workflows vivos 01 y 02 con operaciones atómicas; Nextcloud
  se conserva como artefacto de revisión, no como transporte entre etapas.
- Mantener intactos los artefactos históricos que aún no tienen cuerpo en la
  base; la ingesta los reextraerá desde Dexerto una sola vez, sin una migración
  masiva desde Nextcloud.

### Steps

1. Aplicar la migración idempotente y extender la prueba de contrato SQL.
2. Guardar Markdown en PostgreSQL tras la subida correcta a Nextcloud.
3. Eliminar el nodo de descarga del workflow 02 y construir el prompt desde
   `markdown_content` reclamado en la misma consulta.
4. Probar ambos workflows con datos fijados, sincronizar snapshots y documentar
   la transición para artículos históricos.

### Validation

- El reclamo devuelve `markdown_content` y excluye contenido ausente.
- Las pruebas de los nodos Code confirman que el clasificador no consume datos
  binarios ni rutas de Nextcloud.
- JSON de snapshots válido y equivalente a los workflows vivos relevantes.

## Cambio inmediato: retención de guiones y persistencia de Production

### Goal

Impedir que workflow 04 genere guiones desde artículos Dexerto de más de 72
horas y asegurar que su Production Plan exista en Nextcloud y PostgreSQL antes
de quedar disponible para voz.

### Validation

- `expire_editorial_script_jobs()` deja el trabajo/cola vencidos como `expired`.
- Prueba n8n con datos fijados confirma las rutas `Honi-Scripts` y
  `Honi-Production`, y la persistencia posterior al upload.

## Cambio inmediato: migrar Voice Production a Fish Audio API

### Goal

Generar `narration.wav` desde el workflow canónico 05 con la API oficial de
Fish Audio, preservando los estados de PostgreSQL y el almacenamiento privado
en Nextcloud, sin worker GPU propio.

### Scope

- Deprecar —sin borrar— el worker Docker/Vast/PyWorker, B2 y sus scripts.
- Configurar 05 para `POST https://api.fish.audio/v1/tts`, con Bearer seguro,
  cabecera `model` y `{ text, reference_id, format: "wav" }`.
- Mantener las validaciones de guion, reintentos, idempotencia y ramas de
  fallo existentes.
- Documentar que TTS responde audio binario, no timestamps por palabra; el
  alineamiento será una etapa posterior de CPU.

### Assumptions

- La voz Honi ya está disponible en Fish Audio y el usuario configurará su
  `reference_id` real.
- `s2.1-pro` es el modelo inicial configurable, tal como recomienda la
  documentación vigente de Fish Audio.

### Steps

1. Mover con `git mv` la infraestructura exclusiva de autohospedaje a
   `deprecated/voice-production-worker/` y añadir una nota de retirada.
2. Actualizar atómicamente el workflow vivo 05 y después guardar su snapshot.
3. Añadir una prueba de contrato simulada para URL, cabeceras, body WAV y
   transiciones de éxito/fallo; actualizar ADR y runbook.
4. Ejecutar validaciones estáticas y una prueba n8n con datos fijados. No se
   hará una solicitud real ni se consumirá crédito sin una prueba autorizada.

### Validation

- JSON del workflow válido y snapshot igual al grafo vivo relevante.
- Pruebas de contrato simuladas y comprobaciones de shell/Python de los
  componentes deprecados, sin depender de GPU, Vast o B2.

### Risks

- Una credencial o `reference_id` incorrectos debe terminar en `failed`, no
  dejar el trabajo en `processing`; la prueba E2E real lo comprobará antes de
  activar el workflow.

## Cambio inmediato: simplificar almacenamiento de artículos Dexerto

### Goal

Guardar cada nueva ingesta exclusivamente como Markdown en
`/n8n-youtube-automation/Dexerto-Articles/<fecha>-<slug>.md`.

### Scope

- Eliminar la escritura del JSON de metadatos del workflow 01.
- Volver opcional `article_contents.metadata_uri` mediante una migración
  aditiva.
- Conservar objetos y referencias históricas sin moverlos ni borrarlos.

### Assumptions

- El Markdown conserva los metadatos operativos necesarios para revisión.
- PostgreSQL sigue siendo la fuente de verdad para identidad, URL, hash y
  estados; Nextcloud sólo conserva el artefacto editorial.

### Steps

1. Aplicar la migración idempotente y actualizar el workflow vivo con una
   operación atómica.
2. Probar el compilado de ruta con datos fijados, sin servicios externos.
3. Ejecutar una ingesta manual autorizada, consultar su resultado y sincronizar
   el snapshot, ADR y runbook.

### Validation

- Confirmar que el nuevo registro usa sólo `markdown_uri` y deja
  `metadata_uri` nulo.
- Comprobar en Nextcloud que se creó un único `.md` bajo la nueva ruta.

### Risks

- La ejecución manual puede descubrir artículos nuevos y crear sus filas,
  Markdown y trabajos de clasificación; se mantendrá el workflow inactivo.

## Cambio inmediato: cobertura completa de artículos Dexerto

### Goal

Descubrir todos los artículos elegibles de los últimos siete días desde los
sitemaps mensuales publicados por Dexerto.

### Scope

- Reemplazar `news-sitemap.xml`, que sólo expone una ventana muy reducida, por
  los sitemaps del mes UTC actual y anterior.
- Mantener las secciones permitidas, el corte de siete días y la deduplicación
  editorial existentes.

### Validation

- Probar que el generador produce ambos sitemaps con datos fijos.
- Ejecutar una ingesta manual autorizada y comparar los conteos por nodo y el
  estado final con los artículos creados.

## Cambio inmediato: evitar reingesta de artículos Dexerto almacenados

### Goal

Evitar descargas y escrituras repetidas cuando el scheduler de 30 minutos vuelve
a encontrar un artículo cuyo contenido ya fue almacenado correctamente.

### Scope

- Consultar PostgreSQL por `articles.canonical_url` y `article_contents.status =
  stored` antes de descargar el HTML.
- Dejar pasar sólo URLs que no tengan contenido almacenado.
- No redefinir una política de actualización o reingesta forzada.

### Validation

- Probar con una URL almacenada y otra nueva mediante datos fijos; sólo la nueva
  debe superar el nodo de deduplicación.
- Ejecutar la ingesta manual después de poblar la ventana actual y confirmar que
  no se invocan los nodos de descarga, Nextcloud ni registro editorial.

## Cambio inmediato: converger los disparadores de clasificación

### Goal

Hacer que las ejecuciones manuales, programadas y disparadas por la ingesta
usen exactamente la misma ruta de clasificación de artículos pendientes.

### Scope

- Reemplazar los dos reclamos de lote del workflow 02 por uno solo de hasta 25.
- Añadir un `Execute Workflow Trigger` al workflow 02.
- Invocar el workflow 02 una vez desde el workflow 01 tras registrar artículos.

### Validation

- Probar con datos fijados tanto el trigger manual como el trigger desde
  ingesta, sin reclamar ni clasificar artículos reales.
- Antes de publicar workflow 02, hacer una clasificación manual real autorizada
  y revisar su ejecución y el historial guardado.

## Cambio inmediato: catálogo XLSX en la raíz editorial

### Goal

Mantener el catálogo de revisión como un único archivo fácil de localizar en
`/n8n-youtube-automation/Editorial-Articles-latest.xlsx`.

### Validation

- Ejecutar la exportación manual y comprobar el éxito del nodo de Nextcloud y
  el archivo XLSX generado.

## Cambio inmediato: cerrar TTS Fish en Vast

### Goal

Conectar workflow 05 con el contrato real del worker Fish S2-Pro y dejar los
fallos recuperables sin jobs de voz atascados.

### Validation

- Validar el contrato `/v1/tts` y pruebas unitarias del worker.
- Ejecutar una prueba real autorizada sólo después de configurar endpoint,
  credencial Bearer y artefactos privados.

## Task classification

Documentación, pipeline de datos, contratos e infraestructura local.

## Goal

Completar el pipeline editorial de Honi de forma secuencial y auditable: voz
desde un Production Plan aprobado, aprobación humana, vídeo, publicación y
observabilidad operativa.

## Non-goals

- No activar workflows programados sin una prueba manual satisfactoria por
  etapa.
- No ejecutar, editar ni tomar como base workflows legacy.
- No sustituir PostgreSQL como fuente de verdad ni Nextcloud/OpenCloud como
  almacén de artefactos.
- No versionar credenciales, referencias vocales, audios ni datos editoriales
  privados.

## Current state observations

- Los snapshots en `workflows/` son JSON válido y el Compose actual valida.
- El workflow 05 queda inactivo hasta contar con un adaptador Vast Fish y una
  prueba real autorizada.
- Remotion es un renderer local aislado; aún no tiene contrato de trabajos ni
  integración con n8n.
- La sesión debe cargar el MCP `n8n` con `N8N_MCP_TOKEN` antes de modificar o
  ejecutar workflows vivos. La UI de n8n continúa siendo la fuente de verdad.

## Likely touch points

- `workflows/`, `ops/sql/editorial-schema.sql` y `prompts/editorial/`
- `docs/adr/`, `docs/runbooks/` y `docs/future-roadmap.md`
- `compose.yml`, `remotion-renderer/` y el adaptador Vast Fish externo

## Milestones

### 1. Cerrar la etapa de voz

**Purpose:** convertir únicamente un Production Plan aprobado en un audio WAV
trazable.

**Expected outcome:** el workflow 05 reclama un `voice_job`, valida que los
beats reconstruyen exactamente el guión, llama a `POST /v1/generate`, almacena
el WAV en Nextcloud y persiste éxito, fallo e intentos.

**Likely touch points:** workflow vivo 05 y su snapshot, esquema SQL, variables
de entorno no secretas, ADR 0008 y runbook editorial.

**Validation:** usar `test_workflow` con datos fijados; después de aprobarlo,
una ejecución manual con un único Production Plan listo y consulta de la
ejecución final. No activar el schedule en esta etapa.

**Dependency:** credencial Header Auth del adaptador Vast Fish y
`VAST_FISH_ADAPTER` configurados localmente.

### 2. Incorporar revisión y aprobación humana

**Purpose:** exigir una decisión humana visible entre los artefactos creativos,
de producción, audio y vídeo.

**Expected outcome:** un canal inicial de Discord notifica artefactos pendientes
y permite aprobar, rechazar o devolver a revisión sin sobrescribir historial.

**Likely touch points:** nuevos workflows canónicos, tablas de estado, runbook
editorial y un ADR de la interfaz de aprobación.

**Validation:** pruebas de transición con datos fijados; confirmar que ningún
trabajo no aprobado puede ser reclamado por voz o vídeo.

**Dependency:** definir el bot/canal de Discord y sus credenciales fuera del
repositorio.

### 3. Diseñar e implementar la etapa de vídeo

**Purpose:** generar un vídeo vertical sólo desde audio y Production Plan
aprobados, sin reescribir la narración.

**Expected outcome:** contrato de `video_jobs`, renderer Remotion/Vast y
artefacto final en Nextcloud con estados y reintentos auditables.

**Likely touch points:** ADR nuevo, esquema SQL aditivo, `remotion-renderer/`,
workflow canónico de vídeo y runbook.

**Validation:** composición con paquete fijo en local; `test_workflow` sin
servicios externos; una prueba manual autorizada antes de cualquier schedule.

**Dependency:** decisión explícita sobre la API/cola del renderer antes de
editar arquitectura.

### 4. Añadir publicación aprobada

**Purpose:** publicar sólo vídeos aprobados y evitar duplicados por plataforma.

**Expected outcome:** conectores de YouTube Shorts, TikTok e Instagram Reels
con plataforma, identificador, fecha y resultado persistidos.

**Likely touch points:** workflow(s) canónico(s), tabla de publicaciones, ADR,
runbook y credenciales externas.

**Validation:** pruebas de contrato sin publicar; después, una publicación
manual aprobada por plataforma y verificación del identificador remoto.

**Dependency:** aprobación humana del vídeo y autorización explícita para cada
primera publicación real.

### 5. Consolidar operación y calidad

**Purpose:** hacer observable y recuperable cada etapa antes de automatizarla.

**Expected outcome:** métricas de volumen, estado y fallos; exportación XLSX
periódica; prompts versionados y procedimientos de reintento documentados.

**Likely touch points:** workflow de catálogo, consultas SQL, runbooks y
documentación operativa.

**Validation:** comprobar conteos frente a PostgreSQL, validar snapshots con
`jq empty workflows/*.json`, ejecutar `docker compose config --quiet` y
comparar los snapshots con la UI de n8n mediante MCP.

## Risks

- Las pruebas reales pueden crear artefactos o incurrir en coste de servicios
  externos; requieren autorización por etapa.
- Sin MCP disponible no se deben asumir IDs, estado ni definición de workflows
  vivos a partir de los snapshots.
- Los datos privados ignorados por Git deben conservarse en un respaldo privado
  antes de cualquier limpieza amplia del entorno.

## Reset editorial y ventana de ingesta — 2026-10-26

**Goal:** reiniciar los datos editoriales para una prueba limpia y reducir el
alcance de la ingesta recurrente de Dexerto.

**Scope:** truncar únicamente las tablas de datos del pipeline en la base
`editorial`, sin respaldo por decisión explícita del usuario. Conservar
workflows, credenciales, esquema, funciones, configuración y artefactos de
Nextcloud existentes. Configurar workflow 01 para usar 72 horas en modo manual
y 24 horas en su trigger programado de 30 minutos.

**Assumptions:** el reset elimina todos los artículos, clasificaciones, colas,
guiones y jobs actuales. Los artefactos antiguos de Nextcloud no volverán a
estar referenciados por PostgreSQL.

**Steps:** verificar conteos y dependencias; truncar las tablas de datos con
`RESTART IDENTITY CASCADE`; comprobar que quedaron vacías; actualizar el
workflow vivo 01 de forma atómica; sincronizar su snapshot; validar JSON y
tests de contrato.

**Risks:** no hay recuperación de los datos truncados; una primera ingesta
manual de 72 horas puede producir menos material que una ventana histórica de
cinco días, pero evita artículos que workflow 04 marcaría como `expired`.
