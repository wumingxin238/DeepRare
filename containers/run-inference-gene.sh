#!/usr/bin/env bash
# DeepRare HPO+VCF inference using local Qwen server + mounted data.
#
# Prerequisite: Qwen server running (containers/run-qwen-server.sh).
#
#   export EMBED_APIKEY=sk-...
#   export QWEN_MODEL_DIR=/path/to/Qwen3-14B
#   export DEEPRARE_WORK=/path/to/DeepRare
#   export CUDA_VISIBLE_DEVICES=0
#   bash containers/run-inference-gene.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIF="${DEEPRARE_SIF:-$ROOT/containers/deeprare.sif}"
WORK="${DEEPRARE_WORK:-$ROOT}"
MOUNT="/work"

LOCAL_PORT="${VLLM_PORT:-8000}"
LOCAL_BASE_URL="${LOCAL_BASE_URL:-http://127.0.0.1:${LOCAL_PORT}/v1}"
LOCAL_MODEL="${QWEN_MODEL:-/models/Qwen3-14B}"

EMBED_BASE_URL="${EMBED_BASE_URL:-https://xiaoai.plus/v1}"
EMBED_APIKEY="${EMBED_APIKEY:-${OPENAI_APIKEY:-}}"
EMBED_MODEL="${EMBED_MODEL:-text-embedding-3-small}"
DATASET_NAME="${DATASET_NAME:-case}"
GPU="${CUDA_VISIBLE_DEVICES:-0}"
EXOMISER_JAR="${EXOMISER_JAR:-${MOUNT}/exomiser-cli-14.0.0/exomiser-cli-14.0.0.jar}"

if command -v apptainer >/dev/null 2>&1; then
  SING=apptainer
else
  SING=singularity
fi

if [[ ! -f "$SIF" ]]; then
  echo "Missing $SIF — run: bash containers/build.sh deeprare" >&2
  exit 1
fi
if [[ -z "$EMBED_APIKEY" ]]; then
  echo "Set EMBED_APIKEY (xiaoai sk-... for embedding)." >&2
  exit 1
fi

BINDS=(-B "$WORK:$MOUNT")
if [[ -n "${HF_HOME:-}" ]]; then
  BINDS+=(-B "$HF_HOME:$HF_HOME")
fi

echo "SIF       : $SIF"
echo "Work dir  : $WORK -> $MOUNT"
echo "Qwen API  : $LOCAL_BASE_URL"
echo "Model id  : $LOCAL_MODEL"
echo "GPU       : $GPU"
echo

exec $SING exec --nv --pwd "$MOUNT" "${BINDS[@]}" \
  --env CUDA_VISIBLE_DEVICES="$GPU" \
  --env PYTHONFAULTHANDLER=1 \
  "$SIF" \
  python main_gene.py \
    --model openai \
    --dataset_name "$DATASET_NAME" \
    --search_engine duckduckgo \
    --openai_apikey EMPTY \
    --openai_base_url "$LOCAL_BASE_URL" \
    --openai_model "$LOCAL_MODEL" \
    --openai_mini_model "$LOCAL_MODEL" \
    --openai_embedding_apikey "$EMBED_APIKEY" \
    --openai_embedding_base_url "$EMBED_BASE_URL" \
    --openai_embedding_model "$EMBED_MODEL" \
    --results_folder ./result_gene \
    --exomiser_jar "$EXOMISER_JAR" \
    --exomiser_save_path exomiser_results/
