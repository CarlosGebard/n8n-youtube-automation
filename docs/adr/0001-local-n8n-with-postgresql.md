# ADR 0001: n8n local con PostgreSQL

## Estado

Aceptado.

## Contexto

Se necesita una instancia de n8n Community local para experimentar con automatizaciones. Los flujos, ejecuciones y credenciales deben sobrevivir a la recreación de contenedores.

## Decisión

Ejecutaremos n8n y PostgreSQL con Docker Compose. Ambos servicios guardan sus datos en volúmenes Docker nombrados. n8n escucha únicamente en `127.0.0.1`; PostgreSQL no publica puertos al host y solo es accesible desde la red de Compose.

Los secretos se cargan desde `.env`, que no se versiona. La clave `N8N_ENCRYPTION_KEY` debe conservarse estable mientras haya credenciales almacenadas.

## Consecuencias

- La pila es sencilla de iniciar y eliminar sin perder datos mientras se conserven los volúmenes.
- PostgreSQL evita depender de SQLite para una instalación que puede crecer en ejecuciones y flujos.
- El acceso queda limitado a la máquina local. Para uso remoto se requiere un proxy con TLS, URL pública correcta y `N8N_SECURE_COOKIE=true`.
