#!/usr/bin/env bash
# Smoke-test deeprare.sif on the GPU server (needs singularity/apptainer that can RUN containers).
#
#   conda activate singce
#   cd ~/DeepRare
#   bash containers/test-deeprare-sif.sh
#
# If you see "user namespace disabled", this node cannot run .sif — use conda instead.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIF="${DEEPRARE_SIF:-$ROOT/containers/deeprare.sif}"
WORK="${DEEPRARE_WORK:-$ROOT}"

find_sing() {
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

if ! SING="$(find_sing)"; then
  echo "ERROR: singularity not found (try: conda activate singce)" >&2
  exit 1
fi

if [[ ! -f "$SIF" ]]; then
  echo "ERROR: missing $SIF" >&2
  exit 1
fi

echo "=== deeprare.sif smoke test ==="
echo "Singularity: $SING"
echo "SIF        : $SIF ($(du -h "$SIF" | awk '{print $1}'))"
echo "Work mount : $WORK -> /work"
"$SING" --version 2>/dev/null | head -1 || true
echo

run_test() {
  local label="$1"
  shift
  echo ">>> $label"
  if "$@"; then
    echo "    OK"
  else
    echo "    FAILED (exit $?)"
    return 1
  fi
  echo
}

FAIL=0

run_test "inspect labels" \
  "$SING" inspect "$SIF" || FAIL=1

run_test "python + torch inside container" \
  "$SING" exec "$SIF" python -c \
  "import torch; print('torch', torch.__version__, 'cuda', torch.cuda.is_available())" \
  || FAIL=1

run_test "java (Exomiser)" \
  "$SING" exec "$SIF" java -version \
  || FAIL=1

run_test "DeepRare code present" \
  "$SING" exec "$SIF" python -c \
  "import os; assert os.path.isfile('/opt/deeprare/main_gene.py'); print('main_gene.py OK')" \
  || FAIL=1

run_test "main_gene.py --help (via runscript)" \
  "$SING" run "$SIF" main_gene.py --help \
  || FAIL=1

if [[ -d "$WORK/database" ]]; then
  run_test "mounted project dir (optional)" \
    "$SING" exec -B "$WORK:/work" --pwd /work "$SIF" python -c \
    "import os; print('database entries', len(os.listdir('database')))" \
    || FAIL=1
else
  echo ">>> skip mount test (no $WORK/database on host)"
  echo
fi

if [[ "${TEST_DEEPRARE_GPU:-0}" == "1" ]]; then
  run_test "GPU torch (needs --nv + working driver)" \
    "$SING" exec --nv "$SIF" python -c \
    "import torch; print('cuda', torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')" \
    || FAIL=1
else
  echo ">>> skip GPU test (set TEST_DEEPRARE_GPU=1 to enable)"
  echo
fi

if [[ "$FAIL" -eq 0 ]]; then
  echo "=== All smoke tests passed ==="
else
  echo "=== Some tests failed ==="
  echo "If error mentions 'user namespace disabled', this CentOS 7 node cannot run .sif."
  echo "Use: conda activate deeprare && bash inference_gene_qwen.sh"
  exit 1
fi
