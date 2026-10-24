# ADR 0007: Remotion como renderizador local aislado

## Estado

Aceptado.

## Contexto

El pipeline editorial necesita una etapa de vídeo, pero el primer objetivo es
aprender y validar composición y render de Remotion sin iniciar producción ni
acoplar el servicio a n8n, PostgreSQL o Nextcloud.

## Decisión

Se añade un proyecto independiente en `remotion-renderer/` y un servicio
`remotion-renderer` de Docker Compose, habilitado únicamente con el perfil
`remotion`. Expone Remotion Studio sólo en `127.0.0.1:3000` y contiene una
composición vertical de ejemplo, `HoniIntro`.

El servicio no recibe credenciales, no se conecta a PostgreSQL y no contiene
una API de render. Los MP4 se generan manualmente desde el contenedor durante
esta etapa de aprendizaje.

## Consecuencias

- El stack existente no cambia si se inicia sin el perfil `remotion`.
- Studio permite inspeccionar la composición y editar el código con recarga
  durante desarrollo local.
- La automatización futura requerirá una decisión posterior sobre API, cola,
  almacenamiento de artefactos y contrato de trabajos; no se presupone aquí.
