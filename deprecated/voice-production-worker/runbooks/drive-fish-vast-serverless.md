# Guiones de Google Drive a Fish Audio en Vast Serverless

## Contrato previsto

El endpoint que consumirá n8n será:

```http
POST /v1/generate
Authorization: Bearer $VAST_TTS_TOKEN
Content-Type: application/json

{
  "text": "Texto que se narrará.",
  "reference_id": "vtuber",
  "format": "wav"
}
```

La respuesta satisfactoria contiene audio binario, por ejemplo `audio/wav`. El adaptador interno convierte esta solicitud al MessagePack que requiere el servidor Fish en `http://127.0.0.1:8080/v1/tts`.

No se debe exponer `/v1/references/add`, ni enviar `vtuber.wav` desde n8n.

## Preparar la referencia vocal

1. Mantenga el MP3/WAV y su transcripción fuera de Git.
2. Convierta un MP3 a WAV mono de 24 kHz:

   ```sh
   ffmpeg -i references/vtuber.mp3 -ar 24000 -ac 1 -c:a pcm_s16le references/vtuber.wav
   ```

3. Use una muestra limpia de aproximadamente 15 a 25 segundos y transcriba literalmente lo que dice en `transcript.txt`.
4. Copie ambos archivos a un almacenamiento privado que los workers puedan montar como `/app/references`. No use el filesystem efímero de una instancia ni un repositorio público.

## Preparar el worker

1. Descargue los pesos `fishaudio/s2-pro` al almacenamiento privado y móntelos como `/app/checkpoints`.
2. Inicie la imagen `fishaudio/fish-speech:server-cuda` con `LLAMA_CHECKPOINT_PATH=checkpoints/s2-pro` y `DECODER_CHECKPOINT_PATH=checkpoints/s2-pro/codec.pth`.
3. Espere `GET http://127.0.0.1:8080/v1/health` con respuesta `{"status":"ok"}`.
4. Consulte `/v1/references/list`; si `vtuber` no existe, regístrelo con `POST /v1/references/add`, audio WAV con MIME `audio/wav` y el contenido exacto de `transcript.txt`.
5. Sólo entonces marque el worker como listo. Configure una sola solicitud de inferencia paralela hasta medir la memoria y estabilidad reales.

## Configurar Vast

Use la plantilla Serverless que permita ejecutar el servidor Fish y el PyWorker elegido. Configure:

```text
GPU: RTX 4090, 24 GB VRAM
min_workers: 0
max_workers: 1
min_load: 0
cold_workers: 0
inactivity_timeout: 300
```

Guarde `VAST_TTS_TOKEN` y cualquier secreto de almacenamiento en el gestor de variables de Vast, nunca en el repositorio o el workflow exportado.

## Configurar n8n

El workflow debe permanecer inactivo hasta completar una prueba manual. Sus etapas son:

1. Listar en la carpeta de Drive sólo guiones con estado `listo_para_voz`.
2. Obtener el contenido de cada archivo y validar texto no vacío.
3. Crear `script_hash` y omitir combinaciones ya terminadas de `sourceFileId + script_hash + reference_id`.
4. Segmentar el texto si supera el límite configurado en el worker; procesar segmentos uno a uno.
5. Enviar cada segmento a `POST /v1/generate` y conservar la respuesta como binario.
6. Guardar el audio y un manifiesto JSON con el ID origen, hash, voz, formato y fecha en la carpeta de salida de Drive.

Primero deshabilite el último nodo de Drive, ejecute un guion de prueba corto y escuche el binario obtenido. Habilite la escritura sólo cuando el contenido, la voz y el nombre final sean correctos.

## Diagnóstico

- Si el endpoint devuelve 503 al inicio, espere el arranque en frío y consulte los logs del worker; no reintente en paralelo.
- Si Fish está sano pero el adaptador falla, compare el MessagePack generado con una solicitud de `tools/api_client.py` contra el servidor local.
- Si la voz cambia entre trabajos, verifique el montaje de `/app/references`, el registro de `vtuber` y que cada petición incluya `reference_id`.
- Si se duplican audios, revise el almacén de estados o la tabla de deduplicación antes de activar el Schedule Trigger.
