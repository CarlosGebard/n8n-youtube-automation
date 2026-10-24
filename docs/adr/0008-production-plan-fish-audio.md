# ADR 0008: audio desde Production Plan aprobado

## Estado

Aceptado.

## Contexto

El workflow 05 heredado enumera archivos en Google Drive y los entrega
directamente a Fish. No puede demostrar que el texto fue aprobado, no conoce
el Production Plan y sólo admite el antiguo contrato de Daily News.

## Decisión

El workflow 05 reclama un único `voice_job` creado desde un script aprobado
con `production_status = ready`. `voice_jobs` conserva su relación heredada
con `daily_news_scripts` y añade `individual_script_id`, con una restricción
que exige exactamente una fuente. Los índices únicos parciales hacen que un
script tenga como máximo un audio.

Antes de llamar al adaptador, el workflow comprueba que la concatenación de
`beats[].spoken_text` coincide con `script_text`; luego inserta únicamente
tags permitidos en anchors exactos. La petición usa `POST /v1/generate` y no
expone la API de Fish ni administra alquileres de Vast.

El audio WAV se almacena en Nextcloud. El estado avanza `pending` →
`processing` → `completed` o `failed`, conserva los intentos y el error, y
marca el script como `voiced` sólo tras guardar el archivo.

## Consecuencias

- Se requiere una credencial Header Auth de n8n para el token del adaptador y
  la variable no secreta `VAST_FISH_ADAPTER` para su URL base.
- Un error de adaptador o almacenamiento permanece visible en `voice_jobs` y
  puede reclamarse hasta tres veces.
- El workflow sigue inactivo hasta completar una prueba manual real aprobada.
