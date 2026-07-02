#!/usr/bin/env bash
# Install conda GCC (>=9) for LMDeploy Triton JIT on CentOS 7 (system gcc 4.8 lacks stdatomic.h).
# Usage: conda activate qwen-serve && bash scripts/setup_qwen_gcc.sh

set -euo pipefail

if [[ -z "${CONDA_PREFIX:-}" ]]; then
  echo "Please: conda activate qwen-serve"
  exit 1
fi

echo "Installing conda-forge GCC into $CONDA_PREFIX ..."
conda install -c conda-forge \
  gcc_linux-64=12.4.0 \
  gxx_linux-64=12.4.0 \
  sysroot_linux-64 \
  --no-update-deps -y

export CC="$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-gcc"
export CXX="$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-g++"
export PATH="$CONDA_PREFIX/bin:$PATH"

echo
echo "GCC: $($CC --version | head -1)"
echo
echo "Testing Triton custom add (LMDeploy pytorch backend check)..."
python -m lmdeploy.pytorch.check_env.triton_custom_add

echo
echo "OK. Before starting LMDeploy, run:"
echo "  source scripts/env_qwen_gcc.sh"
