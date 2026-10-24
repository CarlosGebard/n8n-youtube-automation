# Plan: worker Fish Audio para Vast Serverless

## Goal

Publicar una imagen de worker reproducible para Vast Serverless que ejecute Fish Audio S2-Pro y exponga TTS para el futuro workflow de n8n, sin versionar la voz de referencia, pesos ni secretos.

## Scope

- Imagen Docker basada en la imagen CUDA oficial de Fish Speech.
- Arranque de Fish, comprobación de salud y registro idempotente de una referencia privada opcional.
- Configuración PyWorker para proxyar `POST /v1/tts` al servidor Fish local de forma secuencial.
- Contrato JSON compatible con n8n, pruebas unitarias de normalización y documentación de despliegue.
- Workflow de n8n importable e inactivo para transformar archivos de guion de Google Drive en audio.

## Assumptions

- Vast permite usar una plantilla Serverless personalizada que ejecute la imagen publicada.
- Los checkpoints y la referencia se montarán en rutas privadas en tiempo de ejecución.
- La autenticación externa se hará con el token del endpoint de Vast; Fish sólo escucha en loopback y no requiere una clave adicional.

## Steps

1. Crear el contrato de solicitud JSON y el proxy PyWorker para `/v1/tts`.
2. Crear la imagen y script de arranque para Fish S2-Pro y el registro de referencia.
3. Excluir artefactos sensibles y documentar las variables y montajes requeridos.
4. Crear un workflow manual de Drive a TTS con IDs y credenciales vacíos, para que no genere gastos al importarlo.
5. Ejecutar validaciones estáticas y publicar la imagen en un registro antes de crear la plantilla Vast.
6. Probar en una instancia interactiva antes de habilitar Serverless con escala cero.

## Validation

- Las pruebas de contrato y la compilación de Python pasan localmente.
- `bash -n start.sh` no presenta errores.
- En una RTX 4090, el contenedor devuelve `/v1/health`, acepta JSON en `/v1/tts` y registra la referencia una sola vez por arranque.

## Risks

- El primer arranque descarga o monta varios GB de pesos y será lento.
- La API PyWorker se debe validar con la versión de plantilla de Vast antes del despliegue final.
- Un WAV o transcripción añadidos por error al contexto Docker comprometerían la voz; `.dockerignore` los excluye.
