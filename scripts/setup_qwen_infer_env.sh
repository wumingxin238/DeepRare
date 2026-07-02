#!/usr/bin/env bash
# Qwen3 inference env for A800 (same stack as MedRBench setup_a800_env.sh).
# Uses transformers + fp16 — NO vLLM / LMDeploy (CentOS 7 incompatible).
#
#   bash scripts/setup_qwen_infer_env.sh
#   conda activate qwen3_infer

set -eu

QWEN_ENV="${QWEN_ENV:-qwen3_infer}"

_init_conda() {
  if command -v conda >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    source "$(conda info --base)/etc/profile.d/conda.sh"
    return 0
  fi
  for d in "$HOME/miniconda3" "/export/home/$(whoami)/miniconda3"; do
    if [[ -f "${d}/etc/profile.d/conda.sh" ]]; then
      # shellcheck source=/dev/null
      source "${d}/etc/profile.d/conda.sh"
      return 0
    fi
  done
  echo "ERROR: conda not found" >&2
  exit 1
}

_init_conda

if ! conda env list | awk '{print $1}' | grep -qx "$QWEN_ENV"; then
  echo "==> Creating $QWEN_ENV (python 3.10)"
  conda create -n "$QWEN_ENV" python=3.10 -y
fi

conda activate "$QWEN_ENV"
pip install -U pip wheel

echo "==> PyTorch cu121 (works with driver CUDA 12.2)"
pip install torch==2.1.2 torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu121

echo "==> sentencepiece via conda (avoid GCC 4.8 compile on CentOS 7)"
conda install -c conda-forge sentencepiece --no-update-deps -y

echo "==> transformers stack (Qwen3 needs >=4.51, numpy<2)"
pip install \
  "numpy>=1.26,<2" \
  "transformers>=4.51.0,<5.0" \
  "tokenizers>=0.21,<0.22" \
  accelerate \
  bitsandbytes \
  tqdm \
  "huggingface_hub>=0.26,<1.0" \
  fastapi \
  uvicorn

python -c "import torch, transformers; print('OK | torch', torch.__version__, '| transformers', transformers.__version__)"

echo ""
echo "Done. Start OpenAI-compatible server:"
echo "  conda activate $QWEN_ENV"
echo "  CUDA_VISIBLE_DEVICES=1 bash scripts/start_qwen_transformers.sh"
