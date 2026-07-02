#!/usr/bin/env bash
# DeepRare HPO + VCF inference with local Qwen3 (transformers OpenAI server).
#
# Prerequisite (tmux 1):
#   bash scripts/setup_qwen_infer_env.sh
#   conda activate qwen3_infer
#   CUDA_VISIBLE_DEVICES=1 bash scripts/start_qwen_transformers.sh
#
# Prerequisite (tmux 2):
#   conda activate deeprare
#   export EMBED_APIKEY=...   # xiaoai, for embedding only

set -euo pipefail

export PYTHONFAULTHANDLER=1
export CUDA_VISIBLE_DEVICES="${INFER_GPU:-0}"

LOCAL_PORT="${VLLM_PORT:-8000}"
LOCAL_BASE_URL="http://127.0.0.1:${LOCAL_PORT}/v1"
LOCAL_APIKEY="EMPTY"
# Must match scripts/qwen_openai_server.py --model and /v1/models id
LOCAL_MODEL="${QWEN_MODEL:-Qwen/Qwen3-14B}"

EMBED_BASE_URL="${EMBED_BASE_URL:-https://xiaoai.plus/v1}"
EMBED_APIKEY="${EMBED_APIKEY:-${OPENAI_APIKEY:-}}"
EMBED_MODEL="${EMBED_MODEL:-text-embedding-3-small}"

if [[ -z "$EMBED_APIKEY" ]]; then
  echo "Set EMBED_APIKEY to your xiaoai sk-... key (embedding only)."
  exit 1
fi
if ! python - <<'PY'
import os, sys
k = os.environ.get("EMBED_APIKEY", "")
if not k.isascii():
    print("ERROR: EMBED_APIKEY contains non-ASCII characters.", file=sys.stderr)
    print("Use the real sk-... key from inference.sh, not Chinese placeholder text.", file=sys.stderr)
    sys.exit(1)
PY
then
  exit 1
fi

DATASET_NAME="${DATASET_NAME:-case}"
EXOMISER_JAR="${EXOMISER_JAR:-./exomiser-cli-14.0.0/exomiser-cli-14.0.0.jar}"

python main_gene.py \
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
  --results_folder ./result_gene \
  --exomiser_jar "$EXOMISER_JAR" \
  --exomiser_save_path exomiser_results/

# bash inference_gene_qwen.sh
