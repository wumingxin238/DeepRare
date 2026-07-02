#!/usr/bin/env bash
# Install Qwen serving stack in a SEPARATE conda env (do NOT install vllm inside deeprare).
#
# CentOS 7 note: system GCC 4.8 cannot build numpy 2.4 from source.
# This script installs prebuilt numpy via conda-forge BEFORE pip install lmdeploy.
#
# Usage:
#   bash scripts/install_qwen_server.sh          # default: lmdeploy
#   bash scripts/install_qwen_server.sh lmdeploy
#   bash scripts/install_qwen_server.sh vllm

set -euo pipefail

BACKEND="${1:-lmdeploy}"
ENV_NAME="${QWEN_ENV_NAME:-qwen-serve}"

if ! command -v conda >/dev/null 2>&1; then
  echo "conda not found"
  exit 1
fi

eval "$(conda shell.bash hook)"

if conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
  echo "Conda env '$ENV_NAME' already exists, reusing it."
else
  echo "Creating conda env: $ENV_NAME (python 3.11)"
  conda create -n "$ENV_NAME" python=3.11 -y
fi

conda activate "$ENV_NAME"

echo "=== Step 1: prebuilt numpy (avoid GCC 4.8 source build on CentOS 7) ==="
conda install -c conda-forge "numpy=2.1.3" --no-update-deps -y || {
  echo "conda-forge failed, trying pip binary wheel..."
  pip install -U pip wheel
  pip install "numpy==2.1.3" --only-binary=:all:
}

echo "=== Step 2: pip constraints (block numpy source rebuild) ==="
CONSTRAINTS="$(mktemp)"
echo "numpy<2.4" > "$CONSTRAINTS"
pip install -U pip wheel

case "$BACKEND" in
  lmdeploy)
    echo "=== Step 3: install LMDeploy (OpenAI-compatible api_server) ==="
    pip install "lmdeploy>=0.6.0" --prefer-binary -c "$CONSTRAINTS" || {
      echo "Retry lmdeploy without build isolation..."
      pip install "lmdeploy>=0.6.0" --prefer-binary --no-build-isolation -c "$CONSTRAINTS"
    }
    echo
    echo "Done. Start with:"
    echo "  conda activate $ENV_NAME"
    echo "  CUDA_VISIBLE_DEVICES=1 bash scripts/start_qwen_lmdeploy.sh 14"
    ;;
  vllm)
    echo "=== Step 3: install vLLM 0.8.x (separate env, torch 2.6) ==="
    pip install torch==2.6.0 torchvision --index-url https://download.pytorch.org/whl/cu124
    pip install "vllm==0.8.5" --prefer-binary -c "$CONSTRAINTS" || {
      echo
      echo "vllm 0.8.5 wheel failed. Try lmdeploy instead:"
      echo "  bash scripts/install_qwen_server.sh lmdeploy"
      exit 1
    }
    echo
    echo "Done. Start with:"
    echo "  conda activate $ENV_NAME"
    echo "  CUDA_VISIBLE_DEVICES=1 bash scripts/start_qwen_vllm.sh 14"
    ;;
  *)
    echo "Unknown backend: $BACKEND (use lmdeploy or vllm)"
    exit 1
    ;;
esac

rm -f "$CONSTRAINTS"

echo
python - <<'PY'
import numpy
print("numpy", numpy.__version__)
try:
    import lmdeploy
    print("lmdeploy OK")
except ImportError:
    pass
try:
    import vllm
    print("vllm OK")
except ImportError:
    pass
PY

echo
echo "Verify after start:"
echo "  bash scripts/check_qwen_vllm.sh"
