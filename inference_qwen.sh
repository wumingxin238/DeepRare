#!/usr/bin/env bash
# DeepRare HMS inference with local Qwen3 (transformers OpenAI server).
#
# Prerequisite:
#   conda activate qwen3_infer
#   CUDA_VISIBLE_DEVICES=1 bash scripts/start_qwen_transformers.sh
#
# Note: similar-case embeddings still use text-embedding-3-small (prebuilt DB).
# Set EMBED_* to your OpenAI-compatible embedding endpoint (e.g. xiaoai).

set -euo pipefail

export PYTHONFAULTHANDLER=1
export CUDA_VISIBLE_DEVICES="${INFER_GPU:-1}"

# --- local Qwen (vLLM) ---
LOCAL_PORT="${VLLM_PORT:-8000}"
LOCAL_BASE_URL="http://127.0.0.1:${LOCAL_PORT}/v1"
LOCAL_APIKEY="EMPTY"
# Must match `curl ${LOCAL_BASE_URL}/models` -> data[0].id
LOCAL_MODEL="${QWEN_MODEL:-Qwen/Qwen3-14B}"

# --- embedding API (RDS_embeddings.csv was built with text-embedding-3-small) ---
EMBED_BASE_URL="${EMBED_BASE_URL:-https://xiaoai.plus/v1}"
EMBED_APIKEY="${EMBED_APIKEY:-${OPENAI_APIKEY:-}}"
EMBED_MODEL="${EMBED_MODEL:-text-embedding-3-small}"

if [[ -z "$EMBED_APIKEY" ]]; then
  echo "Set EMBED_APIKEY or OPENAI_APIKEY for similarity search embeddings."
  exit 1
fi

DATASET_NAME="${DATASET_NAME:-HMS}"
SERVICE_PATH="${CHROMEDRIVER_PATH:-/usr/local/bin/chromedriver}"

python main.py \
  --model openai \
  --dataset_name "$DATASET_NAME" \
  --search_engine duckduckgo \
  --openai_apikey "$LOCAL_APIKEY" \
  --openai_base_url "$LOCAL_BASE_URL" \
  --openai_model "$LOCAL_MODEL" \
  --openai_mini_model "$LOCAL_MODEL" \
  --openai_embedding_apikey "$EMBED_APIKEY" \
  --openai_embedding_base_url "$EMBED_BASE_URL" \
  --openai_embedding_model "$EMBED_MODEL" \
  --chrome_driver "$SERVICE_PATH" \
  --results_folder ./result

# bash inference_qwen.sh
