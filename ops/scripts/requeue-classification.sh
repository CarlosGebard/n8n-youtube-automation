#!/usr/bin/env sh
set -eu

usage() {
  echo "Usage: $0 --all | --article-id <positive-integer>" >&2
  exit 2
}

scope=${1:-}
value=${2:-}

case "$scope" in
  --all)
    [ -z "$value" ] || usage
    where_clause="TRUE"
    ;;
  --article-id)
    case "$value" in
      ''|*[!0-9]*) usage ;;
    esac
    [ "$value" -gt 0 ] || usage
    where_clause="article_id = $value"
    ;;
  *)
    usage
    ;;
esac

docker compose exec -T postgres psql -U n8n -d editorial -v ON_ERROR_STOP=1 -c \
  "WITH requeued AS (
     UPDATE article_classification_jobs
     SET status = 'pending',
         lock_token = NULL,
         locked_at_utc = NULL,
         last_error = NULL,
         updated_at_utc = now()
     WHERE $where_clause
     RETURNING article_id
   )
   SELECT count(*) AS requeued_articles FROM requeued;"
