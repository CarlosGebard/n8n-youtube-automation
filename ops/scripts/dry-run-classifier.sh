#!/usr/bin/env sh
set -eu

usage() {
  echo "Usage: $0 --article-id <positive-integer>" >&2
  exit 2
}

[ "${1:-}" = "--article-id" ] || usage
article_id=${2:-}
case "$article_id" in
  ''|*[!0-9]*) usage ;;
esac
[ "$article_id" -gt 0 ] || usage

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

[ -f .env ] || {
  echo ".env is required for N8N_MCP_TOKEN" >&2
  exit 1
}
set -a
. ./.env
set +a
[ -n "${N8N_MCP_TOKEN:-}" ] || {
  echo "N8N_MCP_TOKEN is required" >&2
  exit 1
}

article=$(docker compose exec -T postgres psql -U n8n -d editorial -At -v ON_ERROR_STOP=1 -c "
  SELECT json_build_object(
    'id', article.id::text,
    'article_id', article.article_id,
    'title', article.title,
    'source', article.source,
    'canonical_url', article.canonical_url,
    'published_at_utc', article.published_at_utc,
    'markdown_uri', content.markdown_uri
  )::text
  FROM articles AS article
  JOIN article_contents AS content ON content.article_id = article.id
  WHERE article.id = $article_id
    AND content.status = 'stored';
")
[ -n "$article" ] || {
  echo "No stored article found for ID $article_id" >&2
  exit 1
}

test_response=$(jq -n --argjson article "$article" '
  {
    jsonrpc: "2.0",
    id: 1,
    method: "tools/call",
    params: {
      name: "test_workflow",
      arguments: {
        workflowId: "Jabzoiy0VaCyAbxc",
        triggerNodeName: "Probar clasificación manual",
        timeout: 120,
        pinData: {
          "Reclamar artículo por clasificar": [{ json: $article }],
          "Guardar historial LLM": [{ json: { id: "dry-run-no-write" } }],
          "Actualizar estado editorial": [{ json: {} }]
        }
      }
    }
  }
' | curl -fsS -X POST http://localhost:5678/mcp-server/http \
  -H "Authorization: Bearer $N8N_MCP_TOKEN" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2025-03-26' \
  --data-binary @-)

execution_id=$(printf '%s\n' "$test_response" \
  | sed -n 's/^data: //p' \
  | jq -r '.result.content[0].text' \
  | jq -r '.executionId')
[ -n "$execution_id" ] && [ "$execution_id" != "null" ] || {
  printf '%s\n' "$test_response" >&2
  exit 1
}

execution_response=$(curl -fsS -X POST http://localhost:5678/mcp-server/http \
  -H "Authorization: Bearer $N8N_MCP_TOKEN" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2025-03-26' \
  --data "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"get_workflow_execution\",\"arguments\":{\"workflowId\":\"Jabzoiy0VaCyAbxc\",\"executionId\":\"$execution_id\",\"includeData\":true}}}")

printf '%s\n' "$execution_response" \
  | sed -n 's/^data: //p' \
  | jq -r '.result.content[0].text' \
  | jq '.data.resultData.runData["Validar clasificación"][0].data.main[0][0].json.evaluation'
