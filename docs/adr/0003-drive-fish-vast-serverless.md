# ADR 0003: Guiones de Drive narrados por Fish Audio en Vast Serverless

## Estado

Propuesto; pendiente de validación con la plantilla Serverless concreta.

## Contexto

Los guiones ya viven en Google Drive y n8n es la plataforma local de automatización. Se requiere convertir un guion aprobado en narración con una voz VTuber, sin publicar el audio de referencia ni mantener una GPU activa cuando no hay trabajos.

Fish Audio S2-Pro recomienda una GPU con 24 GB de VRAM. Su servidor local recibe TTS mediante MessagePack en `POST /v1/tts`, mientras que n8n está orientado a peticiones HTTP JSON. Vast Serverless permite usar un PyWorker para exponer rutas y gestionar disponibilidad, cola y escalado.

## Decisión

El límite público del servicio será un contrato JSON `POST /v1/generate`, no la API MessagePack de Fish. El adaptador que vive junto al servidor de Fish convertirá la petición en MessagePack y devolverá el audio binario sin recodificarlo. n8n sólo conoce este contrato estable.

El worker se desplegará en Vast Serverless con una RTX 4090 de 24 GB y escalado `0..1`. Los checkpoints de S2-Pro y el WAV junto con su transcripción vivirán en un almacenamiento privado que pueda montar cada worker. El arranque comprobará la salud de Fish y registrará de forma idempotente la referencia `vtuber` antes de aceptar trabajos.

n8n leerá únicamente guiones marcados como listos para locución, llamará al endpoint de forma secuencial y escribirá el audio junto a metadatos de procedencia. La deduplicación se hará mediante el ID del archivo de Drive y un hash del contenido, no por el nombre del archivo.

## Consecuencias

- El workflow se mantiene simple y no depende de librerías MessagePack ni de detalles de S2-Pro.
- La voz y los pesos no se incluyen en el repositorio PyWorker; el repositorio puede permanecer privado igualmente.
- El primer trabajo después de inactividad tendrá la latencia de arranque del contenedor, carga del modelo y registro de referencia.
- Antes de crear el endpoint se debe elegir y probar la plantilla de Vast que arranque a la vez Fish y el PyWorker; no se asumirá compatibilidad de una plantilla de LLM o ComfyUI.
