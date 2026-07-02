#!/usr/bin/env bash
# Start Qwen3-14B OpenAI-compatible server (transformers fp16, MedRBench-style).
# NO vLLM / LMDeploy — works on CentOS 7 + A800.
#
# Prerequisite:
#   bash scripts/setup_qwen_infer_env.sh
#   conda activate qwen3_infer
#
# Usage (tmux recommended):
#   CUDA_VISIBLE_DEVICES=1 bash scripts/start_qwen_transformers.sh

set -euo pipefail

PORT="${VLLM_PORT:-8000}"
GPU="${CUDA_VISIBLE_DEVICES:-1}"
MODEL="${QWEN_MODEL:-Qwen/Qwen3-14B}"
ENABLE_THINKING="${QWEN_ENABLE_THINKING:-0}"

export CUDA_VISIBLE_DEVICES="$GPU"

echo "=== Qwen3 transformers server (MedRBench stack) ==="
echo "Env   : ${CONDA_DEFAULT_ENV:-unknown} (expect qwen3_infer)"
echo "Model : $MODEL"
echo "GPU   : $CUDA_VISIBLE_DEVICES"
echo "URL   : http://127.0.0.1:${PORT}/v1"
echo

if [[ "${CONDA_DEFAULT_ENV:-}" != "qwen3_infer" ]]; then
  echo "WARNING: conda env is not qwen3_infer. Run:"
  echo "  conda activate qwen3_infer"
  echo "  or: bash scripts/setup_qwen_infer_env.sh"
  echo
fi

CMD=(
  python scripts/qwen_openai_server.py
  --model "$MODEL"
  --port "$PORT"
  --host 127.0.0.1
  --fp16
)
if [[ "$ENABLE_THINKING" == "1" ]]; then
  CMD+=(--enable-thinking)
fi
exec "${CMD[@]}"
