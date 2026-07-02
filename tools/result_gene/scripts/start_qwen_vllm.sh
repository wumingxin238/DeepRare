#!/usr/bin/env bash
# Start local Qwen with vLLM (OpenAI-compatible API at http://127.0.0.1:8000/v1)
#
# Usage:
#   bash scripts/start_qwen_vllm.sh          # default 14B
#   bash scripts/start_qwen_vllm.sh 14
#   bash scripts/start_qwen_vllm.sh 32
#   CUDA_VISIBLE_DEVICES=2 bash scripts/start_qwen_vllm.sh 14
#
# After start, verify:
#   bash scripts/check_qwen_vllm.sh

set -euo pipefail

SIZE="${1:-14}"
PORT="${VLLM_PORT:-8000}"
HOST="${VLLM_HOST:-0.0.0.0}"
GPU="${CUDA_VISIBLE_DEVICES:-0}"

export CUDA_VISIBLE_DEVICES="$GPU"

case "$SIZE" in
  14)
    MODEL="${QWEN_MODEL:-Qwen/Qwen2.5-14B-Instruct}"
    EXTRA_ARGS=(--max-model-len 8192)
    ;;
  32)
    MODEL="${QWEN_MODEL:-Qwen/Qwen2.5-32B-Instruct}"
    EXTRA_ARGS=(--max-model-len 8192 --gpu-memory-utilization 0.95)
    ;;
  *)
    echo "Unknown size: $SIZE (use 14 or 32)"
    exit 1
    ;;
esac

echo "=== Qwen vLLM ==="
echo "Model : $MODEL"
echo "GPU   : $CUDA_VISIBLE_DEVICES"
echo "URL   : http://127.0.0.1:${PORT}/v1"
echo

if ! command -v vllm >/dev/null 2>&1; then
  echo "vllm not found in current env."
  echo "Do NOT pip install vllm inside deeprare (torch conflict)."
  echo "Use a separate env instead:"
  echo "  bash scripts/install_qwen_server.sh vllm"
  echo "  conda activate qwen-serve"
  echo "Or use LMDeploy (recommended):"
  echo "  bash scripts/install_qwen_server.sh lmdeploy"
  echo "  conda activate qwen-serve"
  echo "  bash scripts/start_qwen_lmdeploy.sh 14"
  exit 1
fi

echo "Searching local HuggingFace cache for Qwen..."
find "${HF_HOME:-$HOME/.cache/huggingface}/hub" -maxdepth 2 -type d -iname '*qwen*' 2>/dev/null | head -10 || true
echo

exec vllm serve "$MODEL" \
  --host "$HOST" \
  --port "$PORT" \
  --dtype auto \
  --trust-remote-code \
  "${EXTRA_ARGS[@]}"
