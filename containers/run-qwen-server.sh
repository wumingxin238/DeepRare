#!/usr/bin/env bash
# Start Qwen3-14B OpenAI server from qwen-server.sif.
# Model directory is mounted from host — NOT inside the .sif file.
#
#   export QWEN_MODEL_DIR=/path/to/Qwen3-14B   # local HF model folder
#   export CUDA_VISIBLE_DEVICES=5
#   bash containers/run-qwen-server.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_LIBRARY="library://wmx238/deeprare/qwen-server:latest"
SIF="${QWEN_SIF:-$ROOT/containers/qwen-server.sif}"
if [[ "$SIF" != library://* ]] && [[ ! -f "$SIF" ]]; then
  SIF="$DEFAULT_LIBRARY"
  echo "Note: local .sif missing, using Library: $SIF"
fi
MODEL_DIR="${QWEN_MODEL_DIR:?Set QWEN_MODEL_DIR to your local Qwen3-14B folder}"
PORT="${VLLM_PORT:-8000}"
GPU="${CUDA_VISIBLE_DEVICES:-0}"
HOST="${QWEN_HOST:-0.0.0.0}"
MOUNT_MODEL="/models/Qwen3-14B"

if command -v apptainer >/dev/null 2>&1; then
  SING=apptainer
else
  SING=singularity
fi

if [[ "$SIF" != library://* ]] && [[ ! -f "$SIF" ]]; then
  echo "Missing $SIF — build or set QWEN_SIF=library://wmx238/deeprare/qwen-server:latest" >&2
  exit 1
fi
if [[ ! -d "$MODEL_DIR" ]]; then
  echo "Model dir not found: $MODEL_DIR" >&2
  exit 1
fi

export CUDA_VISIBLE_DEVICES="$GPU"

echo "SIF       : $SIF"
echo "Model     : $MODEL_DIR -> $MOUNT_MODEL (read-only)"
echo "GPU       : $CUDA_VISIBLE_DEVICES"
echo "Listen    : http://${HOST}:${PORT}/v1"
echo

exec $SING exec --nv \
  -B "$MODEL_DIR:$MOUNT_MODEL:ro" \
  "$SIF" \
  --model "$MOUNT_MODEL" \
  --port "$PORT" \
  --host "$HOST" \
  --fp16
