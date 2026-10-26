# n8n YouTube Automation · Fish Audio worker

Imagen preparada para un endpoint Vast Serverless que narra guiones de n8n con Fish Audio S2-Pro. El endpoint publica `POST /v1/tts`; acepta JSON y devuelve audio binario. La voz de referencia, los pesos y los secretos nunca forman parte de esta imagen ni de este repositorio.

## Arquitectura

```text
n8n / Google Drive
        │ JSON: text, reference_id, format
        ▼
Vast Serverless → PyWorker → Fish Speech S2-Pro (127.0.0.1:8080)
        │ audio/wav, audio/mpeg, audio/ogg
        ▼
Google Drive: narraciones
```

Fish acepta JSON en `/v1/tts`; por ello PyWorker lo reenvía directamente y no realiza una conversión MessagePack. La petición también puede llevar la envoltura `{"input": {...}}` que usa el cliente de Serverless de Vast.

## Contrato para n8n

```http
POST https://run.vast.ai/route/<ENDPOINT_ID>/v1/tts
Authorization: Bearer <VAST_API_KEY>
Content-Type: application/json

{
  "text": "El guion que se debe narrar.",
  "reference_id": "vtuber",
  "format": "wav",
  "temperature": 0.7,
  "top_p": 0.7
}
```

`text` es obligatorio. Los demás campos respetan los nombres de Fish; `format` puede ser `wav`, `mp3`, `opus` o `pcm`. El token de Vast se guarda como credencial de n8n, no dentro del workflow exportado.

## Preparar artefactos privados

En almacenamiento privado accesible al worker, prepare:

```text
checkpoints/s2-pro/        # pesos de fishaudio/s2-pro, incluido codec.pth
references/vtuber.wav      # WAV mono, 24 kHz, PCM s16le
references/transcript.txt  # transcripción literal de ese WAV
```

La imagen los espera en `/app/checkpoints` y `/app/references` respectivamente. El arranque registra `vtuber` sólo si no aparece ya en `/v1/references/list`.

## Construir y publicar la imagen

Sustituye `REGISTRY/IMAGE:TAG` por una imagen que Vast pueda descargar, por ejemplo GHCR o Docker Hub:

```sh
docker build -t REGISTRY/IMAGE:TAG .
docker push REGISTRY/IMAGE:TAG
```

No construyas con `references/` ni `checkpoints/` en el contexto: `.dockerignore` lo impide como defensa adicional.

## Crear y validar la plantilla Vast

1. Crea una plantilla personalizada que use la imagen publicada y exija una RTX 4090 de 24 GB o más.
2. Monta los directorios privados en `/app/checkpoints` y `/app/references`.
3. Define estas variables en la plantilla o el grupo de workers:

   ```text
   FISH_REFERENCE_ID=vtuber
   FISH_REFERENCE_AUDIO=/app/references/vtuber.wav
   FISH_REFERENCE_TRANSCRIPT=/app/references/transcript.txt
   REQUIRE_REFERENCE=1
   FISH_MAX_TEXT_LENGTH=5000
   ```

4. Crea primero una instancia interactiva. Revisa `/var/log/fish-speech/server.log` y comprueba que Fish responde en `127.0.0.1:8080`.
5. Crea el endpoint Serverless con `min_workers=0`, `max_workers=1`, `min_load=0`, `cold_workers=0` e `inactivity_timeout=300`.
6. Envía un texto corto a `/v1/tts`. Sólo después conecta n8n.

PyWorker se inicia después de que Fish responda al health check. Su benchmark deliberadamente no incluye `reference_id`, para evitar usar la voz privada durante el cálculo de capacidad.

## Validación local sin GPU

Estas validaciones no descargan modelos ni usan la voz:

```sh
python -m unittest discover -s tests -v
python -m py_compile contract.py worker.py register_reference.py
bash -n start.sh
```

La prueba de imagen e inferencia debe realizarse en una GPU NVIDIA con 24 GB de VRAM. Para una prueba de arranque sin la voz real, configura `REQUIRE_REFERENCE=0`.
