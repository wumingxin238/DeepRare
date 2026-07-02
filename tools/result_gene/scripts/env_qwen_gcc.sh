# Source after: conda activate qwen-serve
#   source scripts/env_qwen_gcc.sh

if [[ -n "${CONDA_PREFIX:-}" ]] && [[ -x "$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-gcc" ]]; then
  export CC="$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-gcc"
  export CXX="$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-g++"
  export PATH="$CONDA_PREFIX/bin:$PATH"
fi
