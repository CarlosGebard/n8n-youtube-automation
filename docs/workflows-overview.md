# Workflows de Honi News

Este documento resume los workflows canónicos de la automatización. La UI de
n8n es la fuente de verdad; los JSON en `workflows/` son snapshots versionados.

## Recorrido editorial

```text
01 Ingesta → 02 Clasificación → 03 Agrupación Queue → 04 Guión + Production Plan
                                                              ↓
                                                aprobación humana
                                                              ↓
                                                   05 Voz Fish / Vast
                                                              ↓
                                                    vídeo y publicación
```

## 01 — Dexerto — ingesta editorial

- ID: `PvcuN0zryjedVsbn`
- Entrada: sitemap de Dexerto.
- Salida: contenido del artículo en OpenCloud y artículo/trabajo `pending` en
  PostgreSQL editorial.
- No clasifica ni decide qué se convierte en vídeo.

## 02 — Editorial — clasificar artículos entrantes

- ID: `Jabzoiy0VaCyAbxc`
- Ejecuta el clasificador editorial sobre artículos pendientes.
- Conserva un historial inmutable en `article_classifications`.
- Decide `Individual`, `Queue` o `Discard`.
- `Queue` no es un estado técnico pendiente: pasa al workflow 03.

## 03 — Editorial — agrupar Queue Daily News

- ID: `RAsE71PzfTGz1nxf`
- Recibe sólo artículos clasificados como `Queue`.
- Los agrupa y ordena en una cola `DAILY_ROUNDUP` de 2–3 historias.
- No escribe guiones: prepara el paquete editorial para el workflow 04.

## 04 — Editorial — Creative + Production

- ID: `zGsUUkJ8vONVTclX`
- Reclama una unidad `Individual` (`SINGLE_NEWS`) o una cola Daily News
  (`DAILY_ROUNDUP`).
- **Creative Scriptwriter** genera la narración continua, factual y con la voz
  editorial de Honi.
- **Production Director** conserva literalmente esa narración y la segmenta
  en beats con dirección Fish Audio, avatar, visuales y captions.
- Sube el Markdown creativo y el Production Plan JSON a OpenCloud. PostgreSQL
  conserva el texto, estado y respuestas estructuradas.
- La prueba manual `61` completó ambos agentes correctamente con
  `openai/gpt-6-luna`.

## 05 — Production Plan → Vast Fish Audio

- ID: `mZ1aDnHvsCgmCHr9`
- Sustituye el flujo histórico que leía guiones desde Google Drive.
- Reclama sólo un guion con `approval_status = approved` y
  `production_status = ready` mediante `claim_editorial_voice_job()`.
- Verifica que los beats reconstruyen exactamente `script_text`, inserta sólo
  tags Fish permitidos y solicita un WAV al adaptador Vast Fish.
- El destino previsto es OpenCloud:
  `/n8n-youtube-automation/Honi-News/Audio/<script-id>-<execution-id>.wav`.
- Finalmente registra proveedor, modelo, URI y estado `voiced` en PostgreSQL.
- Estado actual: el grafo principal ya está reemplazado y permanece inactivo.
  Falta asignar la credencial Header Auth del adaptador Vast y completar las
  rutas de recuperación para que un fallo no deje un job en `processing`.
  No se ha ejecutado TTS real.

## Extra — exportar catálogo XLSX

- Exporta una vista transversal de artículos, clasificación, colas, guiones,
  voz y vídeo para revisión editorial.
- Su salida se guarda en `Honi-News/Dexerto-Exports` de OpenCloud.
- Es una utilidad de revisión; no modifica decisiones editoriales.

## Regla de estados

PostgreSQL es la fuente de verdad para estados y relaciones. OpenCloud guarda
artefactos de lectura o producción. Nunca se avanza a la siguiente etapa sólo
porque exista un archivo: se requiere el estado relacional correspondiente.
