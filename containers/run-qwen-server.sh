#!/usr/bin/env bash
# Start Qwen3-14B OpenAI server from qwen-server.sif.
# Model directory is mounted from host — NOT inside the .sif file.
#
#   export QWEN_MODEL_DIR=/path/to/Qwen3-14B   # local HF model folder
#   export CUDA_VISIBLE_DEVICES=5
#   bash containers/run-qwen-server.sh
#
# CentOS 7 without user namespaces: .sif may not run — use qwen3_infer instead:
#   conda activate qwen3_infer
#   export QWEN_MODEL=/path/to/snapshot
#   CUDA_VISIBLE_DEVICES=6 python scripts/qwen_openai_server.py --model "$QWEN_MODEL" --port 8000 --host 0.0.0.0 --fp16

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

find_singularity() {
  if [[ -n "${APPTAINER_BIN:-}" && -x "$APPTAINER_BIN" ]]; then
    echo "$APPTAINER_BIN"
    return 0
  fi
  local d
  for d in \
    "$(command -v singularity 2>/dev/null || true)" \
    "$(command -v apptainer 2>/dev/null || true)" \
    "$HOME/miniconda3/envs/singce/bin/singularity" \
    "/export/home/$(whoami)/miniconda3/envs/singce/bin/singularity"; do
    if [[ -n "$d" && -x "$d" ]]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

if ! SING="$(find_singularity)"; then
  echo "ERROR: singularity/apptainer not found (conda activate singce?)" >&2
  exit 1
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

# singularity run uses %runscript; exec would treat --model as a binary name
exec "$SING" run --nv \
  -B "$MODEL_DIR:$MOUNT_MODEL:ro" \
  "$SIF" \
  --model "$MOUNT_MODEL" \
  --port "$PORT" \
  --host "$HOST" \
  --fp16
