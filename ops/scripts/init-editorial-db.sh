#!/usr/bin/env sh
set -eu

editorial_db=editorial

if ! docker compose exec -T postgres sh -c \
  "psql -U \"\$POSTGRES_USER\" -d postgres -tAc \"SELECT 1 FROM pg_database WHERE datname = '$editorial_db'\"" \
  | grep -q 1; then
  docker compose exec -T postgres sh -c \
    "createdb -U \"\$POSTGRES_USER\" '$editorial_db'"
fi

docker compose exec -T postgres psql -U n8n -d "$editorial_db" -v ON_ERROR_STOP=1 \
  < ops/sql/editorial-schema.sql
