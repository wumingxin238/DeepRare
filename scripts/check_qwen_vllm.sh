#!/usr/bin/env bash
# Check whether local vLLM / Qwen OpenAI-compatible server is up.

PORT="${VLLM_PORT:-8000}"
BASE="http://127.0.0.1:${PORT}/v1"

echo "GET ${BASE}/models"
curl -sS "${BASE}/models" | python -m json.tool || {
  echo
  echo "Server not reachable. Start it with:"
  echo "  tmux new -s qwen-vllm 'bash scripts/start_qwen_vllm.sh 14'"
  exit 1
}

echo
echo "Quick chat test..."
curl -sS "${BASE}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer EMPTY" \
  -d '{
    "model": "'"${QWEN_MODEL:-Qwen/Qwen2.5-14B-Instruct}"'",
    "messages": [{"role": "user", "content": "Reply with OK only."}],
    "max_tokens": 16
  }' | python -m json.tool
