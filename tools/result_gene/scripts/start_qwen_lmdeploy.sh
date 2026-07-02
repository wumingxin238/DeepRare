#!/usr/bin/env bash
# Start Qwen with LMDeploy (OpenAI-compatible API at http://127.0.0.1:8000/v1)
#
# Prerequisite:
#   conda activate qwen-serve
#   bash scripts/setup_qwen_gcc.sh   # CentOS 7 only, if Triton fails
#
# Usage:
#   CUDA_VISIBLE_DEVICES=1 bash scripts/start_qwen_lmdeploy.sh 14

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env_qwen_gcc.sh"

SIZE="${1:-14}"
PORT="${VLLM_PORT:-8000}"
GPU="${CUDA_VISIBLE_DEVICES:-1}"
BACKEND="${LMDEPLOY_BACKEND:-turbomind}"

export CUDA_VISIBLE_DEVICES="$GPU"

case "$SIZE" in
  14)
    MODEL="${QWEN_MODEL:-Qwen/Qwen2.5-14B-Instruct}"
    ;;
  32)
    MODEL="${QWEN_MODEL:-Qwen/Qwen2.5-32B-Instruct}"
    ;;
  *)
    echo "Unknown size: $SIZE (use 14 or 32)"
    exit 1
    ;;
esac

if ! command -v lmdeploy >/dev/null 2>&1; then
  echo "lmdeploy not found. conda activate qwen-serve first."
  exit 1
fi

echo "=== LMDeploy Qwen ==="
echo "Model   : $MODEL"
echo "GPU     : $CUDA_VISIBLE_DEVICES"
echo "Backend : $BACKEND  (set LMDEPLOY_BACKEND=pytorch to force pytorch)"
echo "URL     : http://127.0.0.1:${PORT}/v1"
if [[ -n "${CC:-}" ]]; then
  echo "CC      : $CC"
fi
echo

exec lmdeploy serve api_server "$MODEL" \
  --server-port "$PORT" \
  --model-name "$MODEL" \
  --session-len 8192 \
  --backend "$BACKEND"
