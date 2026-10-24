# Runbook: Remotion renderer local

## Alcance

Este servicio sirve para aprender Remotion y renderizar la composición de
ejemplo manualmente. No está conectado a n8n, PostgreSQL, Nextcloud ni al
pipeline editorial.

## Arranque

Desde la raíz del repositorio:

```sh
docker compose --profile remotion up -d --build remotion-renderer
docker compose --profile remotion ps
```

Abra `http://127.0.0.1:3000`. Studio debe mostrar la composición vertical
`HoniIntro` (1080×1920, 30 fps, 5 segundos). Los cambios en
`remotion-renderer/src/` se reflejan durante la ejecución local.

## Renderizar el ejemplo

```sh
docker compose --profile remotion exec remotion-renderer npm run render:sample
```

El resultado queda en `remotion-renderer/out/honi-intro.mp4`.

## Diagnóstico

```sh
docker compose --profile remotion logs --tail=100 remotion-renderer
docker compose --profile remotion ps
```

Si Chromium no inicia, conserve los logs completos. Las bibliotecas requeridas
por Chromium se instalan dentro de la imagen; no instale dependencias de
Remotion en el host.

## Parada

```sh
docker compose --profile remotion stop remotion-renderer
```

La parada conserva la imagen, el volumen de dependencias y los renders bajo
`remotion-renderer/out/`.
