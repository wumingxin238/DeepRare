#!/usr/bin/env bash
# Build DeepRare Singularity/Apptainer images on Linux (GPU server).
#
#   cd /path/to/DeepRare
#   bash containers/build.sh          # both images
#   bash containers/build.sh deeprare
#   bash containers/build.sh qwen-server
#
# Requires: apptainer or singularity, root or fakeroot for build.
#
# Long build — run in tmux (CentOS 7: remote build only):
#   tmux new -s sif-build
#   conda activate singce
#   cd ~/DeepRare && sed -i 's/\r$//' containers/*.sh containers/*.def
#   # Build smaller image first (~5GB):
#   REMOTE_BUILD=1 bash containers/build.sh qwen-server 2>&1 | tee containers/build-qwen.log
#   REMOTE_BUILD=1 bash containers/build.sh deeprare 2>&1 | tee containers/build-remote.log
#   # Sylabs free tier: 60 min total per build (compile + upload). Ctrl+b d to detach.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINERS="$ROOT/containers"
STAGING="$CONTAINERS/staging"
# Remote build respects .gitignore — do NOT put upload artifacts under containers/staging/
DEEPRARE_TAR="$CONTAINERS/deeprare.tar.gz"
QWEN_SCRIPT="$CONTAINERS/qwen_openai_server.py"

find_apptainer() {
  if [[ -n "${APPTAINER_BIN:-}" && -x "$APPTAINER_BIN" ]]; then
    echo "$APPTAINER_BIN"
    return 0
  fi
  local d
  for d in \
    "$(command -v singularity 2>/dev/null || true)" \
    "$(command -v apptainer 2>/dev/null || true)" \
    "$HOME/apptainer/bin/singularity" \
    "$HOME/apptainer/bin/apptainer" \
    "$HOME/.local/bin/apptainer" \
    "/usr/local/bin/apptainer" \
    "/usr/bin/apptainer" \
    "/usr/local/bin/singularity" \
    "/usr/bin/singularity"; do
    if [[ -n "$d" && -x "$d" ]]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

if SING="$(find_apptainer)"; then
  :
else
  echo "ERROR: apptainer/singularity not found." >&2
  echo "  Install: bash containers/install-apptainer.sh" >&2
  echo "  Or ask cluster admin to install apptainer module." >&2
  exit 1
fi
echo "Using: $SING"

TARGET="${1:-all}"

rsync_deeprare() {
  echo "==> Staging DeepRare source (exclude large/runtime data)..."
  rm -rf "$STAGING/deeprare" "$DEEPRARE_TAR"
  mkdir -p "$STAGING/deeprare"
  rsync -a \
    --exclude='.git' \
    --exclude='database' \
    --exclude='database/' \
    --exclude='data/' \
    --exclude='dataset/' \
    --exclude='exomiser-cli-*' \
    --exclude='exomizer-cli-*' \
    --exclude='exomiser-cli-*' \
    --exclude='exomiser_results' \
    --exclude='exomiser_results/' \
    --exclude='result' \
    --exclude='result/' \
    --exclude='result_gene' \
    --exclude='result_gene/' \
    --exclude='containers/staging' \
    --exclude='containers/*.sif' \
    --exclude='containers/*.log' \
    --exclude='*.sif' \
    --exclude='*.zip' \
    --exclude='*.tar' \
    --exclude='*.tar.gz' \
    --exclude='*.tgz' \
    --exclude='models' \
    --exclude='models/' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.conda' \
    "$ROOT/" "$STAGING/deeprare/"
  tar -czf "$DEEPRARE_TAR" -C "$STAGING/deeprare" .
  local size_mb
  size_mb="$(du -m "$DEEPRARE_TAR" | awk '{print $1}')"
  echo "    tarball: ${size_mb}M ($DEEPRARE_TAR)"
  if [[ "$size_mb" -gt 500 ]]; then
    echo "ERROR: tarball too large (${size_mb}M > 500M)." >&2
    echo "  Large files still under DeepRare? Check:" >&2
    du -sh "$STAGING/deeprare"/* 2>/dev/null | sort -hr | head -10 >&2
    exit 1
  fi
}

rsync_qwen() {
  echo "==> Staging Qwen server script..."
  cp "$ROOT/scripts/qwen_openai_server.py" "$QWEN_SCRIPT"
  echo "    script: $QWEN_SCRIPT"
}

build_one() {
  local name="$1"
  local def="$CONTAINERS/${name}.def"
  local build_def_rel="${name}.def"
  local out="$CONTAINERS/${name}.sif"
  if [[ ! -f "$def" ]]; then
    echo "Missing $def" >&2
    exit 1
  fi
  echo "==> Building $out (this may take 20-60 min)..."
  cd "$CONTAINERS"
  if [[ "${REMOTE_BUILD:-0}" == "1" ]]; then
    export DEEPRARE_GIT_URL="${DEEPRARE_GIT_URL:-https://github.com/wumingxin238/DeepRare.git}"
    export DEEPRARE_GIT_REF="${DEEPRARE_GIT_REF:-main}"
    export DEEPRARE_GIT_RAW="${DEEPRARE_GIT_RAW:-https://raw.githubusercontent.com/wumingxin238/DeepRare}"
    mkdir -p "$CONTAINERS/.remote-build"
    build_def_rel=".remote-build/${name}.def"
    envsubst '${DEEPRARE_GIT_URL} ${DEEPRARE_GIT_REF} ${DEEPRARE_GIT_RAW}' < "$def" > "$CONTAINERS/$build_def_rel"
    echo "    source: git clone ${DEEPRARE_GIT_URL} @ ${DEEPRARE_GIT_REF} (push to GitHub first)"
  else
    if [[ "$name" == "deeprare" && ! -f deeprare.tar.gz ]]; then
      echo "Missing $DEEPRARE_TAR" >&2
      exit 1
    fi
    if [[ "$name" == "qwen-server" && ! -f qwen_openai_server.py ]]; then
      echo "Missing $QWEN_SCRIPT" >&2
      exit 1
    fi
  fi
  if [[ "${REMOTE_BUILD:-0}" != "1" ]]; then
    echo "ERROR: local build needs root/fakeroot (not available on this CentOS 7 node)." >&2
    echo "  Use remote build:" >&2
    echo "    REMOTE_BUILD=1 bash containers/build.sh $name" >&2
    exit 1
  fi
  BUILD_ARGS=()
  if [[ "${REMOTE_BUILD:-0}" == "1" ]]; then
    if [[ "$SING" == *apptainer* ]] && "$SING" build --help 2>&1 | grep -qi "Apptainer"; then
      echo "ERROR: Apptainer 1.5+ removed --remote build." >&2
      echo "  Use SingularityCE instead:" >&2
      echo "    conda create -n singce -c conda-forge singularityce -y" >&2
      echo "    conda activate singce" >&2
      echo "    singularity remote login    # token from https://cloud.sylabs.io" >&2
      echo "    REMOTE_BUILD=1 bash containers/build.sh $name" >&2
      echo "  Or build via web: https://cloud.sylabs.io/builder" >&2
      exit 1
    fi
    echo "    (using Sylabs remote builder — need: singularity remote login)"
    BUILD_ARGS+=(--remote)
  elif "$SING" build --help 2>&1 | grep -q fakeroot; then
    BUILD_ARGS+=(--fakeroot)
  fi
  if "$SING" build "${BUILD_ARGS[@]}" "$out" "$build_def_rel"; then
    echo "OK: $out"
  else
    echo "Build failed." >&2
    echo "Options:" >&2
    echo "  1) singularity remote login && REMOTE_BUILD=1 bash containers/build.sh $name" >&2
    echo "  2) Keep using conda: bash inference_gene_qwen.sh" >&2
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
case "$TARGET" in
  deeprare)
    if [[ "${REMOTE_BUILD:-0}" != "1" ]]; then
      rsync_deeprare
    fi
    build_one deeprare
    ;;
  qwen-server)
    if [[ "${REMOTE_BUILD:-0}" != "1" ]]; then
      rsync_qwen
    fi
    build_one qwen-server
    ;;
  all)
    if [[ "${REMOTE_BUILD:-0}" != "1" ]]; then
      rsync_deeprare
      rsync_qwen
    fi
    build_one deeprare
    build_one qwen-server
    ;;
  *)
    echo "Usage: $0 [deeprare|qwen-server|all]" >&2
    exit 1
    ;;
esac

echo ""
echo "Done. Images:"
ls -lh "$CONTAINERS"/*.sif 2>/dev/null || true
echo ""
echo "Next:"
echo "  export QWEN_MODEL_DIR=/path/to/Qwen3-14B"
echo "  bash containers/run-qwen-server.sh"
echo "  export EMBED_APIKEY=sk-..."
echo "  bash containers/run-inference-gene.sh"
fi
