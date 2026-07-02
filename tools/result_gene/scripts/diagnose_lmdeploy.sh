#!/usr/bin/env bash
# Diagnose LMDeploy TurboMind / Triton issues.
set -euo pipefail

echo "=== Python / lmdeploy ==="
python -c "import lmdeploy; print('lmdeploy', lmdeploy.__version__)"

echo
echo "=== TurboMind import ==="
python - <<'PY' || true
try:
    from lmdeploy import turbomind
    print("turbomind: OK")
except Exception as e:
    print("turbomind: FAILED ->", e)
PY

echo
echo "=== _turbomind.so location ==="
python - <<'PY' || true
import glob, lmdeploy, os
root = os.path.dirname(lmdeploy.__file__)
for p in glob.glob(root + "/**/_turbomind*.so", recursive=True):
    print(p)
PY

echo
echo "=== GCC ==="
echo "system: $(gcc --version 2>/dev/null | head -1 || echo missing)"
if [[ -n "${CONDA_PREFIX:-}" ]] && [[ -x "$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-gcc" ]]; then
  echo "conda : $($CONDA_PREFIX/bin/x86_64-conda-linux-gnu-gcc --version | head -1)"
else
  echo "conda gcc: not installed (run bash scripts/setup_qwen_gcc.sh)"
fi

echo
echo "=== Triton check ==="
if [[ -f "$(dirname "$0")/env_qwen_gcc.sh" ]]; then
  # shellcheck disable=SC1091
  source "$(dirname "$0")/env_qwen_gcc.sh"
fi
python -m lmdeploy.pytorch.check_env.triton_custom_add 2>&1 || echo "Triton check FAILED"
