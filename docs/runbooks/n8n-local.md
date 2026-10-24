# Runbook: n8n Community local

## Requisitos

- Docker Engine en ejecución.
- Docker Compose v2 (`docker compose version`).

## Primer arranque

Desde la raíz del repositorio:

```sh
cp .env.example .env
```

Edite `.env` y sustituya `POSTGRES_PASSWORD` y `N8N_ENCRYPTION_KEY` por valores largos y únicos. Por ejemplo:

```sh
openssl rand -base64 32
```

Inicie la instancia:

```sh
docker compose up -d
docker compose ps
```

Abra `http://localhost:5678` y cree la cuenta propietaria inicial. n8n mantendrá los datos en los volúmenes `postgres_data` y `n8n_data`.

El prompt editorial versionado se monta desde `prompts/editorial/agent_categorizer.md` como archivo de sólo lectura. Si cambia su ubicación o contenido, recree sólo n8n para actualizar el montaje:

```sh
docker compose up -d --force-recreate n8n
```

## Verificación y diagnóstico

```sh
docker compose ps
curl -f http://localhost:5678/healthz
docker compose logs --tail=100 n8n
```

Ambos contenedores deben aparecer como `healthy`. Si n8n no inicia, revise que las variables de `.env` no estén vacías y los registros de PostgreSQL.

### DNS de feeds y servicios privados

El servicio `n8n` usa MagicDNS de Tailscale (`100.100.100.100`) y Cloudflare (`1.1.1.1`) como respaldo. Así puede resolver servicios privados del tailnet y sitios públicos como Dexerto. Si un nodo HTTP informa un error DNS, recree n8n y compruebe desde el contenedor:

```sh
docker compose up -d --force-recreate n8n
docker compose exec -T n8n getent hosts www.dexerto.com
```

## Operación diaria

```sh
# Detener sin borrar datos
docker compose stop

# Volver a iniciar
docker compose start

# Seguir registros de n8n
docker compose logs -f n8n
```

## Actualización

Respalde PostgreSQL antes de actualizar. Después:

```sh
docker compose pull
docker compose up -d
docker compose ps
```

Conserve sin cambios `N8N_ENCRYPTION_KEY`. Cambiarla impide descifrar las credenciales existentes.

## Respaldo y restauración

Respaldo lógico de la base de datos:

```sh
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > n8n-backup.sql
```

Para restaurar, con la pila detenida o n8n detenido:

```sh
docker compose stop n8n
docker compose exec -T postgres psql -U "$POSTGRES_USER" "$POSTGRES_DB" < n8n-backup.sql
docker compose start n8n
```

El archivo de respaldo puede incluir datos sensibles: guárdelo cifrado y fuera del repositorio.

## Eliminación

Para retirar contenedores y red, preservando datos:

```sh
docker compose down
```

Para borrar permanentemente los datos de n8n y PostgreSQL:

```sh
docker compose down -v
```

Use el último comando solo si desea perder todos los flujos, ejecuciones y credenciales.
