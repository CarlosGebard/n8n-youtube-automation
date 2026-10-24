#!/usr/bin/env bash
set -Eeuo pipefail

log_dir="${FISH_LOG_DIR:-/var/log/fish-speech}"
mkdir -p "$log_dir"

checkpoint_dir="${FISH_CHECKPOINTS_DIR:-/app/checkpoints/s2-pro}"
codec_path="${FISH_CODEC_PATH:-${checkpoint_dir}/codec.pth}"
api_port="${FISH_API_PORT:-8080}"
max_text_length="${FISH_MAX_TEXT_LENGTH:-5000}"
fish_python="${FISH_PYTHON:-/app/.venv/bin/python}"

cleanup() {
  if [[ -n "${fish_pid:-}" ]]; then
    kill "$fish_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

"$fish_python" tools/api_server.py \
  --listen "127.0.0.1:${api_port}" \
  --llama-checkpoint-path "$checkpoint_dir" \
  --decoder-checkpoint-path "$codec_path" \
  --max-text-length "$max_text_length" \
  >"$log_dir/server.log" 2>&1 &
fish_pid=$!

for attempt in $(seq 1 180); do
  if curl --fail --silent --show-error "http://127.0.0.1:${api_port}/v1/health" >/dev/null; then
    /opt/fish-vast/venv/bin/python /opt/fish-vast/register_reference.py
    exec /opt/fish-vast/venv/bin/python /opt/fish-vast/worker.py
  fi
  if ! kill -0 "$fish_pid" 2>/dev/null; then
    cat "$log_dir/server.log" >&2 || true
    exit 1
  fi
  sleep 2
done

echo "Fish Speech did not become healthy within six minutes." >&2
cat "$log_dir/server.log" >&2 || true
exit 1
