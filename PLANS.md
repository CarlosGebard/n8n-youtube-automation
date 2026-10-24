# Plan: renderizador local de Remotion

---

# Plan: Workflow 05 — Production Plan a audio Fish

## Goal

Sustituir el flujo legado de Google Drive por un workflow editorial que genere
audio sólo desde una narración aprobada y su Production Plan listo.

## Scope

- Generalizar `voice_jobs` para Daily News e Individual sin duplicar audios.
- Validar que los beats reconstruyen literalmente la narración y compilar tags
  Fish permitidos mediante anchors exactos.
- Llamar al contrato estable `POST /v1/generate`, guardar el WAV en Nextcloud
  y registrar resultado, fallos y reintentos.

## Assumptions

- El adaptador Vast aporta sus propias credenciales, modelo Fish y referencia
  vocal; n8n sólo envía `script_id`, texto compilado, `voice_id` y formato.
- El workflow queda inactivo hasta una prueba manual autorizada.

## Steps

1. Aplicar una migración aditiva e idempotente de `voice_jobs` y reclamo
   atómico para ambos tipos de script.
2. Reemplazar el grafo vivo de 05 con nodos PostgreSQL, compilador, adaptador
   Vast, Nextcloud y persistencia de resultado.
3. Sincronizar el snapshot, ADR y runbook; probar el compilador con datos
   fijados sin invocar servicios externos.

## Validation

- Aplicar el esquema y consultar constraints, índices y función.
- Validar los JSON de workflows y `docker compose config`.
- Usar `test_workflow` con un plan listo de ejemplo cuando el MCP esté
  disponible; no se ejecutará TTS real sin una aprobación adicional.

## Goal

Levantar Remotion Studio en un contenedor local, aislado del pipeline
editorial, para aprender a editar y renderizar una composición de prueba.

## Scope

- Proyecto Remotion mínimo y una composición vertical `HoniIntro`.
- Servicio de Compose optativo bajo el perfil `remotion`.
- ADR y runbook de operación local.

## Assumptions

- Docker Engine local está disponible para el usuario actual.
- Esta entrega no integra Remotion con n8n, PostgreSQL, Nextcloud, voz ni
  workflows.

## Steps

1. Definir el proyecto y fijar versiones coherentes de los paquetes Remotion.
2. Empaquetarlo en una imagen con las bibliotecas de Chromium requeridas.
3. Añadir el servicio sólo en el perfil `remotion`, expuesto exclusivamente en
   loopback.
4. Levantar Studio y renderizar el MP4 de muestra manualmente.

## Validation

- `docker compose config` valida la topología.
- El contenedor queda saludable y Studio responde en `127.0.0.1:3000`.
- `npm run render:sample` crea `out/honi-intro.mp4`.

## Risks

- La primera construcción descarga dependencias Node y es más lenta.
- Un host sin permisos para el socket Docker no puede levantar el contenedor.

---

# Plan: normalización por etapas del pipeline editorial

## Plan: Creative Scriptwriter y Production Director separados

## Goal

Separar la creación de narración y la dirección audiovisual en dos agentes y
workflows independientes, con aprobación humana obligatoria entre ambos.

## Scope

- Creative genera sólo el JSON del guión y el Markdown legible.
- Production recibe únicamente un guión aprobado y genera el plan Fish/avatar/
  visuales/Remotion sin modificar una letra de la narración.
- PostgreSQL conserva respuestas, estados de aprobación y producción por
  separado.

## Assumptions

- La aprobación se realiza explícitamente mediante un comando operativo.
- El modelo de ambos agentes es `gemini/gemini-3.8-flash`.
- TTS y render no se ejecutan en esta entrega.

## Validation

- El contrato creativo exige 160–300 palabras y cobertura factual válida.
- El contrato de producción exige que los beats reconstruyan el script exacto.
- Ningún trabajo sin aprobación puede ser reclamado por Production.

---

## Plan: artefactos de guión Markdown en OpenCloud

## Goal

Guardar cada guión de lectura editorial como Markdown en OpenCloud, mientras
PostgreSQL conserva el estado, relaciones y respuesta estructurada del modelo.

## Scope

- Cambiar sólo el artefacto cargado por el workflow 04 de `.json` a `.md`.
- Mantener `script_uri`, `script_text` y `raw_response` existentes como fuente
  relacional y técnica.
- Reintentar el trabajo Individual ya creado para comprobar el Markdown real.

## Validation

- Confirmar éxito de la ejecución manual, URI `.md` y estado `scripted`.
- Comprobar que todos los nodos del workflow 04 terminan y que el snapshot es
  JSON válido.

---

## Plan: guiones para decisiones Individual y Daily News

## Goal

Permitir que el workflow de guión reclame exactamente una unidad editorial:
un artículo clasificado `Individual` o una cola `Daily News`, sin mezclar sus
estados ni artefactos.

## Scope

- Añadir trabajos y resultados de guión para `Individual`.
- Cambiar el workflow 04 para reclamar cualquiera de los dos formatos y
  persistirlo en su tabla y carpeta de Nextcloud correspondientes.
- Actualizar el clasificador, documentación operativa y ADR del contrato.

## Assumptions

- `Queue` conserva su recorrido Prompt 2 → `DAILY_ROUNDUP`.
- Un `Individual` se convierte en un paquete `SINGLE_NEWS` con una sola
  historia y sus hechos ya clasificados.
- Voz y vídeo individuales quedan fuera de esta entrega.

## Steps

1. Aplicar una migración SQL aditiva para trabajos, guiones y reclamo atómico
   de ambos formatos.
2. Al persistir una clasificación `Individual`, crear o reactivar su trabajo
   de guión.
3. Ajustar los nodos de reclamo, preparación, almacenamiento y persistencia
   del workflow 04 sin alterar Prompt 3.
4. Crear la carpeta de artefactos Individual en Nextcloud, sincronizar los
   snapshots y actualizar ADR/runbook.

## Validation

- Aplicar el esquema de forma idempotente y consultar los nuevos objetos.
- Validar los JSON de workflows con `jq`.
- Consultar el workflow vivo después de la mutación y ejecutar una prueba
  manual autorizada cuando exista un trabajo `Individual` elegible.

## Risks

- Un flujo que no encuentre ningún trabajo devuelve cero ítems; se conservará
  este comportamiento, pero el runbook documentará ambas fuentes de trabajo.

---

# Plan: normalización por etapas del pipeline editorial

## Goal

Separar la ingesta, clasificación, agrupación de artículos `Queue`, guiones Daily News, voz y vídeo en contratos relacionales explícitos, manteniendo PostgreSQL como fuente de verdad y Nextcloud como almacén de artefactos.

## Scope

- Migración SQL aditiva y retrocompatible desde el estado editorial actual.
- Ajuste de los workflows canónicos de ingesta, clasificación y exportación para usar los nuevos límites de etapa.
- Definición e importación de los workflows inactivos de agrupación `Queue` y guión Daily News.
- Prompts versionados, ADR, runbook, README y guía de agentes alineados con la nueva operación.

## Assumptions

- `Individual` conserva su clasificación y queda disponible para una ruta futura de guión individual.
- Sólo `Queue` entra al prompt de agrupación y después al prompt de guión Daily News.
- Las credenciales existentes de PostgreSQL, Nextcloud y LiteLLM se reutilizan; ningún secreto se versiona.

## Steps

1. Obtener los workflows vivos y confirmar sus contratos actuales antes de mutarlos.
2. Añadir tablas de contenido, trabajos de clasificación, colas Daily News, pertenencias de cola y guiones; migrar los datos actuales sin eliminar columnas heredadas.
3. Ajustar la ingesta y clasificación para escribir sólo sus tablas de etapa y conservar historial inmutable de LLM.
4. Crear los flujos inactivos de agrupación `Queue` y generación de guión Daily News con prompts versionados y validación estricta de JSON.
5. Corregir la ruta viva de exportación XLSX a `Honi-News/Dexerto-Exports` y ampliar su catálogo para reflejar el estado por etapa.
6. Actualizar snapshots, ADR, runbook, README y `AGENTS.md`; validar JSON, SQL y la coincidencia entre snapshots y UI.

## Validation

- `psql` aplica el esquema de forma idempotente en la base `editorial`.
- `jq empty` valida todos los snapshots.
- El MCP de n8n valida las mutaciones y confirma los nodos/rutas de los workflows vivos.
- Las pruebas con datos fijados no invocan LiteLLM, Nextcloud, TTS ni vídeo.

## Risks

- Las columnas heredadas de clasificación no se eliminan en esta entrega para preservar datos y permitir reversión.
- Los prompts de agrupación y guión producen artefactos editoriales; los nuevos workflows permanecerán inactivos hasta una prueba manual autorizada.

---

# Plan: corrección y prueba del filtro editorial vivo

## Goal

Corregir en la UI activa de n8n el filtro de fechas del workflow `01 — Dexerto — ingesta editorial` y comprobar una ejecución manual de extremo a extremo.

## Scope

- Sustituir el uso exclusivo de `lastmod` por una fecha normalizada que acepte `lastmod` o `news:news["news:publication_date"]`.
- Mantener alineado el export versionado con el workflow vivo.
- Ejecutar una prueba manual y revisar los conteos y el nodo terminal mediante la API de n8n.

## Assumptions

- La UI activa es la fuente de verdad y la API key local sólo se usa para leer y actualizar ese workflow identificado por ID.
- La prueba puede crear artículos nuevos sólo cuando superen la deduplicación existente en Nextcloud y PostgreSQL.

## Steps

1. Obtener la definición vigente de la UI y modificar sólo el código del nodo de filtro.
2. Actualizar el export equivalente del repositorio.
3. Ejecutar el workflow manualmente desde n8n y consultar el resultado de cada nodo relevante.
4. Confirmar que la salida no se detiene en el filtro y reportar cualquier fallo posterior sin aplicar cambios adicionales.

## Validation

- Validar el JSON del export con `jq`.
- Confirmar por API el `lastNodeExecuted`, estado de ejecución y conteos de salida de filtro, descarga, almacenamiento y registro.

## Risks

- Dexerto puede cambiar nuevamente la estructura del sitemap; el workflow conservará la condición de fecha y descartará entradas sin ninguna fecha reconocida.
- Una prueba con artículos no vistos puede escribir contenido editorial real; las capas existentes de deduplicación limitan duplicados, pero no se desactivarán para la prueba.

---

# Plan: auditoría, retirada, separación y reubicación editorial

## Goal

Documentar el estado verificable de los flujos del repositorio, retirar los exports obsoletos, separar la ingesta editorial y trasladar sus rutas de Nextcloud a la estructura Honi-News, sin cambiar sus contratos de datos.

## Scope

- Inspección de workflows n8n, configuración de ejecución, esquema editorial, worker de TTS y documentación asociada.
- Retirada de los exports inactivos `dexerto-drive-ingestion`, `dexerto-cleanup-to-trash`, `kotaku-drive-ingestion-base` y `kotaku-games-article-links`.
- Separación del workflow editorial en tres módulos numerados: ingesta, clasificación y exportación.
- Creación de un XLSX vacío de catálogo y actualización de las rutas Nextcloud para artículos y exportaciones.
- Configuración explícita de DNS para que n8n conserve MagicDNS y resuelva feeds públicos.
- Validación estática de JSON, Python y Compose cuando las herramientas estén disponibles.
- Informe sin cambiar flujos, infraestructura ni secretos.

## Assumptions

- Los JSON versionados representan plantillas importables; su estado real tras importar a n8n requiere comprobación en la instancia.
- Las credenciales y datos de ejecución no están versionados.

## Steps

1. Inventariar la estructura, configuración de runtime y contratos persistentes.
2. Reconstruir cada flujo desde sus nodos, conexiones y disparadores, contrastándolo con runbooks y ADRs.
3. Retirar sólo los cuatro exports inactivos autorizados tras verificar sus nombres y referencias.
4. Cortar la ingesta después de registrar el artículo como pendiente, y reutilizar los workflows independientes de clasificación y exportación.
5. Numerar los módulos operativos sin alterar sus credenciales, datos ni frecuencias.
6. Crear el XLSX inicial y cambiar sólo las rutas versionadas de Nextcloud a Honi-News.
7. Configurar DNS explícito para n8n y verificar la resolución desde el contenedor.
8. Ejecutar validaciones estáticas y señalar de forma separada los aspectos que no se pueden confirmar sin una instancia o credenciales.
9. Entregar el mapa actual, dependencias, estado de activación y riesgos priorizados.

## Validation

- Parsear todos los JSON de workflows con `jq`.
- Compilar los módulos Python y ejecutar sus pruebas si las dependencias están disponibles.
- Ejecutar `docker compose config` sólo si existe una configuración local no sensible disponible.

## Risks

- La ausencia de `.git` en este directorio impide atribuir cambios a una revisión concreta.
- Un workflow exportado puede diferir de la versión importada y activa en n8n.

---

# Plan: instancia local de n8n Community

## Goal

Proveer una instancia local y persistente de n8n Community para explorar automatizaciones, accesible en `http://localhost:5678`.

## Scope

- Orquestación local con Docker Compose.
- n8n respaldado por PostgreSQL y volúmenes Docker persistentes.
- Configuración sensible fuera de control de versiones y ejemplo seguro para crearla.
- Documentación de decisión y operación local.

## Assumptions

- El equipo dispone de Docker Engine y Docker Compose v2.
- El uso inicial es exclusivamente local; no se expone la instancia a Internet.

## Steps

1. Definir los servicios, red interna, volúmenes y comprobaciones de salud en Compose.
2. Añadir una plantilla `.env.example` con valores de desarrollo y generar instrucciones para secretos reales.
3. Documentar la decisión de usar PostgreSQL y el procedimiento de arranque, verificación, parada, actualización y respaldo.

## Validation

- Ejecutar `docker compose config` con un `.env` local válido.
- Arrancar los servicios y comprobar que ambos queden saludables.
- Verificar la respuesta HTTP de `http://localhost:5678`.

## Risks

- La clave de cifrado y la contraseña de PostgreSQL no deben cambiarse después de crear credenciales sin un procedimiento de migración.
- La configuración HTTP sin cookie segura es adecuada solo para localhost; una exposición pública requiere TLS y configuración de URL pública.

---

# Plan: pipeline editorial Dexerto con PostgreSQL, Nextcloud y LiteLLM

## Goal

Sustituir la ingesta editorial basada en Google Drive por un pipeline inactivo y recuperable donde PostgreSQL mantiene el estado relacional, Nextcloud conserva el contenido de cada artículo y LiteLLM clasifica artículos ya almacenados mediante `agent_categorizer.md`.

## Scope

- Crear una base de datos editorial aislada dentro de la instancia PostgreSQL existente, con esquema para artículos, evaluaciones LLM, historias, asociaciones, ejecuciones y exportaciones.
- Adaptar el workflow Dexerto para persistir Markdown y metadatos JSON en Nextcloud, con deduplicación por URL canónica y hash de contenido.
- Añadir un workflow de clasificación que reclama de forma exclusiva artículos pendientes, descarga su contenido desde Nextcloud, valida la respuesta JSON del clasificador y persiste la decisión.
- Añadir un workflow de exportación que produce una copia XLSX compatible conceptualmente con `Editorial-Database.xlsx` y la sube a Nextcloud.
- Desactivar y documentar la retirada de la purga de Google Drive de esta cadena.

## Assumptions

- Nextcloud se configurará en n8n con una contraseña de aplicación y tendrá una carpeta destinada al pipeline.
- LiteLLM se configurará después como endpoint OpenAI-compatible; ninguna clave de proveedor se incluirá en workflows exportados.
- `agent_categorizer.md` es el contrato de clasificación versionado y se montará en n8n como archivo de solo lectura.
- La base `n8n` y sus tablas internas no se usarán para el estado editorial.

## Steps

1. Definir el esquema SQL idempotente y un procedimiento de inicialización para la base editorial, manteniendo la URL de origen única y trazabilidad del contenido, clasificación y ejecuciones.
2. Añadir el montaje de prompts de solo lectura y los archivos de configuración necesarios, sin exponer puertos ni secretos adicionales.
3. Reemplazar el workflow de ingesta Dexerto por una versión inactiva que registre el artículo, guarde `article.md` y `source.json` en Nextcloud, y deje el artículo en `classification_status=pending` sólo tras una escritura confirmada.
4. Crear el workflow inactivo de clasificación LiteLLM y el de exportación XLSX a Nextcloud, usando credenciales sin identificar hasta que el usuario las configure.
5. Actualizar runbooks, ADR y validaciones; no modificar ni borrar los documentos históricos de Google Drive.

## Validation

- Validar JSON de todos los workflows y sintaxis SQL.
- Ejecutar `docker compose config`.
- Probar el esquema contra PostgreSQL local y consultar sus restricciones e índices.
- Tras configurar credenciales, ejecutar primero cada workflow manualmente con un artículo de prueba y sin activar schedules.

## Risks

- Nextcloud y PostgreSQL no comparten una transacción; el estado `content_status` debe impedir la clasificación de una carga incompleta y permitir reintentos.
- Un XLSX es una exportación de auditoría, no el almacén de estado ni un mecanismo de bloqueo.
- El contenido editorial es entrada no confiable: se delimitará como tal y el modelo deberá responder sólo el JSON definido por el prompt.

---

# Plan: extracción de enlaces de artículos de Kotaku

## Goal

Crear un flujo de n8n que lea el RSS de la sección Games de Kotaku y emita por cada artículo su URL canónica individual junto con sus metadatos básicos.

## Scope

- Lectura manual del feed `https://kotaku.com/games/feed`.
- Normalización de los enlaces individuales y metadatos del RSS.
- Flujo importable y documentación de uso.

## Assumptions

- El RSS de Kotaku continúa exponiendo `link` como URL canónica de cada `item`.

## Steps

1. Leer el feed con el nodo RSS Feed Read.
2. Reducir cada elemento a `articleUrl`, título, fecha de publicación y resumen.
3. Importar el flujo en la instancia local de n8n.

## Validation

- Ejecutar el flujo manualmente y confirmar que `articleUrl` contiene URL individuales de `kotaku.com`.

## Risks

- Kotaku puede cambiar la estructura o disponibilidad del feed; el flujo depende del campo RSS `link`.

---

# Plan: base de ingesta Kotaku a Google Drive

## Goal

Crear un workflow de n8n, visible e inactivo, para probar la carga de artículos de Kotaku de los últimos siete días y dejar preparado el monitoreo periódico.

## Scope

- Dos entradas: ejecución manual paginada para backfill y Schedule Trigger para novedades.
- Lectura RSS, normalización, filtro de siete días y preparación de un archivo Markdown por artículo.
- Nodo Google Drive deshabilitado, sin credenciales ni identificadores de carpetas.

## Assumptions

- El usuario conectará su propia credencial Google Drive OAuth2 en n8n.
- La primera ejecución de prueba se hará manualmente antes de activar el Schedule Trigger.

## Steps

1. Crear el workflow base con las dos rutas de inicio y la paginación del feed.
2. Añadir nodos de transformación que produzcan un archivo listo para Drive.
3. Importar el workflow como inactivo y verificar que n8n lo reconoce.

## Validation

- Validar la sintaxis JSON e importar el workflow en la instancia local.
- Confirmar que queda inactivo y que los nodos de Drive no tienen credenciales asociadas.

## Risks

- El nodo de Drive permanece deshabilitado hasta que se seleccione la credencial y carpeta de destino.
- La deduplicación durable debe habilitarse antes de activar el monitoreo para prevenir copias repetidas.

---

# Plan: contenido completo de artículos Dexerto en Drive

## Goal

Extender el workflow de Dexerto para que cada Google Doc incluya el texto extraído de la página individual, además de los metadatos del sitemap.

## Scope

- Descargar cada `articleUrl` que pase el filtro existente.
- Extraer el cuerpo editorial legible desde el HTML, con una alternativa si el selector principal cambia.
- Mantener la credencial y la carpeta de Drive ya configuradas.

## Assumptions

- Las páginas públicas de Dexerto siguen sirviendo el texto en HTML a la instancia local de n8n.
- La primera validación se ejecutará sin el nodo Drive para no crear archivos de prueba adicionales.

## Steps

1. Inspeccionar el HTML real de una URL reciente y elegir selectores estables del artículo.
2. Insertar nodos de descarga y extracción entre el filtro y la preparación del documento.
3. Incluir el contenido extraído en `documentBody` y actualizar la nota visible del workflow.
4. Validar el flujo de forma segura antes de escribir en Drive.

## Validation

- Confirmar que el extractor devuelve texto no vacío, URL y fecha para una página reciente.
- Validar el JSON del workflow y que conserva la configuración de Drive en la instancia.

## Risks

- Dexerto puede cambiar su HTML o servir una página anti-bot; el workflow debe omitir el artículo si no logra obtener un cuerpo válido, en lugar de guardar contenido vacío.

---

# Plan: retención de documentos Dexerto en Google Drive

## Goal

Mantener `Gaming-News` con tres días calendario de publicaciones mediante una purga diaria y recuperable.

## Scope

- Listar únicamente documentos de `Gaming-News`.
- Interpretar la fecha de publicación desde el prefijo `YYYY-MM-DD-` del nombre.
- Enviar a la papelera los documentos publicados antes del inicio del día de hace tres días.

## Assumptions

- Los documentos del flujo Dexerto conservan ese prefijo de fecha.
- En la zona horaria de la instancia, el 15 de octubre se deben purgar los del 11 de octubre o anteriores.

## Steps

1. Crear un workflow con disparador manual y una programación diaria a las 00:10.
2. Listar el contenido de la carpeta, filtrar por fecha de publicación y omitir nombres inválidos.
3. Usar la operación de Drive que mueve los candidatos a la papelera, sin borrado permanente.
4. Activar el workflow sin realizar una purga manual durante la instalación.

## Validation

- Validar el JSON y probar el filtro con fechas de ejemplo para comprobar que el 11 se purga el día 15 y el 12 se conserva.
- Verificar que el workflow importado está activo y conserva la carpeta y credencial previstas.

## Risks

- El corte usa fechas calendario porque los nombres no contienen hora de publicación; el comportamiento solicitado equivale a conservar los tres días calendario más recientes.

---

# Plan: guiones de Google Drive a voz VTuber en Vast Serverless

## Goal

Crear una integración reproducible en la que n8n lea guiones aprobados de Google Drive, solicite su narración a un endpoint serverless de Vast.ai que ejecute Fish Audio S2-Pro con la voz VTuber privada, y guarde el audio resultante en una carpeta de salida de Drive.

## Scope

- Un workflow n8n importable, inicialmente inactivo, para descubrir y procesar guiones desde una carpeta concreta de Google Drive.
- Un contrato HTTP JSON estable entre n8n y el endpoint de Vast, independiente del protocolo MessagePack interno de Fish.
- Un worker de Vast que arranque Fish Audio S2-Pro, espere su health check, registre la referencia de voz de forma idempotente y traduzca JSON a MessagePack antes de invocar `POST /v1/tts` localmente.
- Almacenamiento privado y persistente para los checkpoints y la referencia vocal; el repositorio no contendrá el WAV, transcripción ni secretos.
- Configuración prevista para una RTX 4090 de 24 GB, con cero workers en reposo y un worker máximo.

## Assumptions

- Los guiones están en una carpeta de Google Drive a la que la credencial OAuth de n8n tiene acceso.
- El audio de ElevenLabs permanece local y el usuario cuenta con permiso para usarlo como referencia vocal.
- Se usará Fish Audio S2-Pro y la imagen oficial `fishaudio/fish-speech:server-cuda` como base de la imagen de inferencia.
- Antes del despliegue se elegirá un almacenamiento privado montable por cada worker para `checkpoints/` y `references/`.

## Steps

1. Acordar el contrato `POST /v1/generate`: entrada JSON con `text`, `reference_id`, `format` y parámetros opcionales de muestreo; salida de audio binario con `Content-Type` correcto. El endpoint no aceptará ni expondrá el WAV de referencia.
2. Crear el repositorio privado del worker con la imagen de Fish, el adaptador PyWorker, un script de arranque y pruebas de contrato. El adaptador serializará la petición al MessagePack que exige Fish y reenviará sin alterar los bytes de audio devueltos.
3. Preparar el volumen privado: descargar allí `fishaudio/s2-pro`, copiar `vtuber.wav` y `transcript.txt`, y registrar `vtuber` al arrancar sólo si aún no existe. Una referencia se volverá a registrar después de cada arranque en frío si el servidor no la persiste fuera del proceso.
4. Crear el endpoint Serverless con GPU RTX 4090 (24 GB), `min_workers=0`, `max_workers=1`, `min_load=0`, `cold_workers=0` e `inactivity_timeout=300`. Protegerlo con un token propio del endpoint y limitar las rutas públicas al contrato acordado.
5. Crear el workflow n8n inactivo: listar guiones pendientes en Drive, extraer y validar texto, segmentarlo por límites del modelo, llamar secuencialmente a Vast, unir o conservar los fragmentos y subir el resultado a la carpeta de audio de Drive. Registrar `sourceFileId`, hash del guion, `reference_id`, endpoint y estado para deduplicación y reintentos.
6. Probar primero un guion corto con la escritura de Drive deshabilitada; después habilitar la salida y, por último, activar el Schedule Trigger.

## Validation

- En una RTX 4090, `GET /v1/health` devuelve `{"status":"ok"}` tras cargar S2-Pro.
- El arranque registra o reutiliza la referencia `vtuber` sin necesitar que el WAV esté en Git ni en el disco efímero del worker.
- Una petición JSON válida produce audio WAV/MP3 reproducible y una inválida devuelve un error HTTP útil sin iniciar inferencia.
- Una ejecución manual de n8n lee un guion de prueba, conserva su trazabilidad y produce exactamente un archivo de salida; una segunda ejecución del mismo hash no duplica el audio.
- Se confirma que el endpoint llega a cero workers después de cinco minutos inactivo y que el siguiente trabajo completa tras un arranque en frío.

## Risks

- Los arranques en frío pueden ser largos por el peso de S2-Pro; los checkpoints deben residir en almacenamiento persistente próximo al worker.
- Un PyWorker de Vast debe verificarse contra la versión exacta de la plantilla elegida, porque sus rutas de escucha, logs de disponibilidad y forma de proxy pueden variar.
- Google Docs puede contener formato y texto editorial que no debe narrarse; el workflow debe definir una marca o campo de estado explícito antes de automatizar la lectura.
- El token de Vast, las credenciales OAuth y la voz de referencia son datos sensibles y sólo deben configurarse como secretos o en almacenamiento privado.

---

# Plan: organización profesional del repositorio

## Goal

Ordenar los archivos locales por responsabilidad sin perder assets, datos, workflows ni configuración de ejecución.

## Scope

- Crear directorios explícitos para `assets/`, `data/` y `prompts/`.
- Reubicar los dos XLSX como datos editoriales y el MP3 como referencia de audio.
- Reubicar el prompt editorial y actualizar el montaje de Compose que lo consume.
- Añadir un README de raíz y actualizar el runbook operativo para reflejar las rutas nuevas.

## Assumptions

- Los XLSX y el MP3 son archivos locales que se deben conservar, no artefactos a regenerar ni eliminar.
- `workflows/`, `docs/`, `ops/` y el repositorio independiente `n8n-youtube-automation/` ya representan límites útiles y se mantendrán en su ubicación actual.

## Steps

1. Crear la jerarquía de datos, assets y prompts sin modificar contenido binario.
2. Mover los cuatro archivos raíz a la categoría correspondiente y actualizar el bind mount de n8n.
3. Documentar la estructura, la distinción entre snapshots de workflow y fuente de verdad n8n, y el paso de recreación necesario para adoptar el nuevo montaje.
4. Validar las rutas, hashes de los archivos movidos, JSON de workflows y resolución de Compose.

## Validation

- Comparar los hashes SHA-256 de los tres archivos binarios antes y después del movimiento.
- Ejecutar `jq empty workflows/*.json` y `docker compose config`.
- Confirmar que no quedan assets, datos ni prompts operativos dispersos en la raíz.

## Risks

- El contenedor de n8n actualmente en ejecución conserva el montaje anterior hasta recrearse; el runbook indicará el comando preciso y no se recreará sin necesidad.
- Los datos locales no están contenidos en el repositorio Git anidado; su conservación depende del directorio de trabajo y de una estrategia de respaldo separada.
