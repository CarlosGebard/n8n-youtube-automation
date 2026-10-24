# Plan futuro de Honi News

Hoja de ruta resumida, en orden de dependencia.

## 1. Cerrar la voz (workflow 05)

- Crear en n8n la credencial Header Auth del adaptador Vast Fish.
- Definir `VAST_FISH_ADAPTER` con un endpoint estable y recrear n8n si cambia
  el entorno.
- Añadir y probar rutas de fallo: compilador, adaptador y OpenCloud deben
  dejar `voice_jobs.failed`, guardar `last_error` y devolver el guion a
  `ready` conservando los intentos.
- Probar primero con un Production Plan aprobado y un audio real controlado.

## 2. Revisión y aprobación humana

- En desarrollo: revisar el Markdown creativo y el Production Plan JSON en
  OpenCloud.
- Integrar un bot de Discord para notificar cada artefacto pendiente y aceptar
  aprobar, rechazar o reenviar a revisión.
- Más adelante, usar el mismo canal para aprobar audio, vídeo final y orden de
  publicación. WhatsApp queda como alternativa, no como primer canal.

## 3. Vídeo

- Crear el workflow que recibe sólo audio aprobado y Production Plan aprobado.
- Enviar el paquete al renderer de Remotion/Vast.
- Generar vídeo vertical y guardar el resultado en OpenCloud con su estado en
  `video_jobs`.
- Mantener la separación: el renderer no puede reescribir guiones ni alterar
  decisiones editoriales.

## 4. Publicación

- Añadir aprobación explícita del vídeo final.
- Implementar conectores de YouTube Shorts, TikTok e Instagram Reels.
- Registrar plataforma, identificador de publicación, fecha y resultado para
  evitar duplicados.

## 5. Operación y calidad

- Activar schedules sólo después de pruebas manuales exitosas por etapa.
- Mantener exportación XLSX periódica para auditoría editorial rápida.
- Añadir métricas: artículos ingeridos/clasificados, grupos creados, guiones
  aprobados, fallos de voz y vídeos publicados.
- Versionar prompts y conservar ejecuciones/artefactos para comparar ajustes
  de calidad sin borrar historial.
