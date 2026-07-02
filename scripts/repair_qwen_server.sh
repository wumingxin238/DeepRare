#!/usr/bin/env bash
# Quick repair when qwen-serve env exists but lmdeploy install failed on numpy build.
set -euo pipefail

ENV_NAME="${QWEN_ENV_NAME:-qwen-serve}"

eval "$(conda shell.bash hook)"
conda activate "$ENV_NAME"

echo "Installing prebuilt numpy via conda-forge..."
conda install -c conda-forge "numpy=2.1.3" --no-update-deps -y

CONSTRAINTS="$(mktemp)"
echo "numpy<2.4" > "$CONSTRAINTS"

pip install -U pip wheel
pip install "lmdeploy>=0.6.0" --prefer-binary -c "$CONSTRAINTS" || \
  pip install "lmdeploy>=0.6.0" --prefer-binary --no-build-isolation -c "$CONSTRAINTS"

rm -f "$CONSTRAINTS"

python -c "import numpy; import lmdeploy; print('numpy', numpy.__version__); print('lmdeploy OK')"
