#!/usr/bin/env bash
# Fallback: start Qwen with vLLM in qwen-serve env (torch already installed by lmdeploy).
# Use when LMDeploy TurboMind/Triton fails on CentOS 7.
#
#   conda activate qwen-serve
#   pip install "vllm==0.8.5" --prefer-binary -c <(echo "numpy<2.4")
#   CUDA_VISIBLE_DEVICES=1 bash scripts/start_qwen_vllm_fallback.sh 14

set -euo pipefail

SIZE="${1:-14}"
PORT="${VLLM_PORT:-8000}"
GPU="${CUDA_VISIBLE_DEVICES:-1}"

export CUDA_VISIBLE_DEVICES="$GPU"

case "$SIZE" in
  14) MODEL="${QWEN_MODEL:-Qwen/Qwen2.5-14B-Instruct}" ;;
  32) MODEL="${QWEN_MODEL:-Qwen/Qwen2.5-32B-Instruct}" ;;
  *) echo "use 14 or 32"; exit 1 ;;
esac

if ! command -v vllm >/dev/null 2>&1; then
  echo "Installing vllm 0.8.5 (one-time)..."
  pip install "vllm==0.8.5" --prefer-binary -c <(echo "numpy<2.4") || {
    echo "vllm install failed"
    exit 1
  }
fi

echo "=== vLLM Qwen (fallback) ==="
echo "Model: $MODEL"
echo "GPU  : $CUDA_VISIBLE_DEVICES"
echo "URL  : http://127.0.0.1:${PORT}/v1"
echo

exec vllm serve "$MODEL" \
  --host 0.0.0.0 \
  --port "$PORT" \
  --dtype auto \
  --max-model-len 8192
