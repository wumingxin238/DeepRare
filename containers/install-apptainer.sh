#!/usr/bin/env bash
# Install Apptainer on GPU-A800 / CentOS 7 (no root).
#
# CentOS 7 note: upstream install-unprivileged.sh often fails (EOL mirrors).
# This script prefers conda-forge on el7.
#
#   bash containers/install-apptainer.sh
#   source ~/.bashrc
#   apptainer --version

set -eo pipefail

INSTALL_DIR="${APPTAINER_INSTALL_DIR:-$HOME/apptainer}"
APPTAINER_VERSION="${APPTAINER_VERSION:-1.3.4}"
CONDA_ENV="${APPTAINER_CONDA_ENV:-apptainer}"

_is_el7() {
  [[ -f /etc/os-release ]] && grep -qE 'VERSION_ID="?7' /etc/os-release
}

_init_conda() {
  if [[ -n "${CONDA_EXE:-}" ]]; then
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
  return 1
}

_write_bashrc() {
  local bin_path="$1"
  local marker="# DeepRare Apptainer"
  grep -q "$marker" "$HOME/.bashrc" 2>/dev/null && return 0
  cat >> "$HOME/.bashrc" <<EOF

$marker
export PATH="$INSTALL_DIR/bin:\$PATH"
export APPTAINER_BIN="$bin_path"
EOF
  echo "==> Added PATH to ~/.bashrc"
}

install_via_conda() {
  echo "==> Installing apptainer via conda-forge (env: $CONDA_ENV)"
  _init_conda

  if ! conda env list | awk '{print $1}' | grep -qx "$CONDA_ENV"; then
    conda create -n "$CONDA_ENV" python=3.10 -y
  fi
  conda activate "$CONDA_ENV"

  if ! conda install -y -c conda-forge "apptainer=${APPTAINER_VERSION}"; then
    echo "==> Retry: latest apptainer from conda-forge"
    conda install -y -c conda-forge apptainer
  fi

  local real_bin
  real_bin="$(command -v apptainer)"
  mkdir -p "$INSTALL_DIR/bin"
  ln -sf "$real_bin" "$INSTALL_DIR/bin/apptainer"
  ln -sf apptainer "$INSTALL_DIR/bin/singularity"
  echo "$real_bin"
}

install_via_unprivileged_el7() {
  echo "==> Trying upstream unprivileged installer (el7, may fail on EOL mirrors)"
  local script_url="https://raw.githubusercontent.com/apptainer/apptainer/main/tools/install-unprivileged.sh"
  rm -rf "$INSTALL_DIR"
  curl -s "$script_url" | bash -s - -e -d el7 -v 1.1.9 "$INSTALL_DIR"
  echo "$INSTALL_DIR/bin/apptainer"
}

install_via_github_rpm() {
  echo "==> Trying GitHub RPM + dependency extract (often fails on el7 mirrors)"
  local ver="1.1.9"
  local rpm="apptainer-${ver}-1.x86_64.rpm"
  local url="https://github.com/apptainer/apptainer/releases/download/v${ver}/${rpm}"
  local tmp script_url
  tmp="$(mktemp -d)"
  script_url="https://raw.githubusercontent.com/apptainer/apptainer/main/tools/install-unprivileged.sh"
  curl -fsSL "$url" -o "$tmp/$rpm"
  rm -rf "$INSTALL_DIR"
  curl -s "$script_url" | bash -s - -e -d el7 -v "$tmp/$rpm" "$INSTALL_DIR"
  rm -rf "$tmp"
  echo "$INSTALL_DIR/bin/apptainer"
}

echo "==> Apptainer install -> $INSTALL_DIR"
if _is_el7; then
  echo "    Detected CentOS/RHEL 7 — using conda-first strategy"
fi

BIN=""
if _is_el7; then
  BIN="$(install_via_conda)" || true
else
  BIN="$(install_via_unprivileged_el7)" || BIN="$(install_via_conda)" || true
fi

if [[ -z "$BIN" || ! -x "$BIN" ]]; then
  BIN="$(install_via_unprivileged_el7)" || true
fi
if [[ -z "$BIN" || ! -x "$BIN" ]]; then
  BIN="$(install_via_github_rpm)" || true
fi
if [[ -z "$BIN" || ! -x "$BIN" ]]; then
  BIN="$(install_via_conda)" || true
fi

if [[ -z "$BIN" || ! -x "$BIN" ]]; then
  echo ""
  echo "ERROR: Could not install apptainer." >&2
  echo "Workarounds:" >&2
  echo "  A) Ask admin to install apptainer / enable user namespaces" >&2
  echo "  B) Build .sif on Ubuntu/WSL, scp to server" >&2
  echo "  C) Skip Singularity — conda already works:" >&2
  echo "       bash inference_gene_qwen.sh" >&2
  exit 1
fi

_write_bashrc "$BIN"
export PATH="$INSTALL_DIR/bin:$PATH"
export APPTAINER_BIN="$BIN"

echo ""
"$BIN" --version || true
echo ""

if [[ -r /proc/sys/user/max_user_namespaces ]]; then
  ns="$(cat /proc/sys/user/max_user_namespaces)"
  echo "user.max_user_namespaces=$ns"
  if [[ "$ns" == "0" ]]; then
    echo ""
    echo "NOTE: user namespaces disabled on this node."
    echo "  Local 'apptainer build' may fail."
    echo "  Use remote build:"
    echo "    apptainer remote login"
    echo "    REMOTE_BUILD=1 bash containers/build.sh"
  fi
fi

echo ""
echo "OK. Next:"
echo "  source ~/.bashrc"
echo "  tmux new -s sif-build"
echo "  bash containers/build.sh 2>&1 | tee containers/build.log"
