#!/usr/bin/env bash
# Discover an existing local Qwen / vLLM deployment on the server.

echo "=== GPU usage (nvidia-smi) ==="
nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory --format=csv,noheader 2>/dev/null || nvidia-smi | tail -n 20

echo
echo "=== Running vLLM / Ollama / Qwen processes ==="
ps aux | grep -E 'vllm|ollama|qwen|fastchat|lmdeploy' | grep -v grep || echo "(none matched)"

echo
echo "=== OpenAI-compatible endpoints ==="
for port in 8000 8001 11434 8080; do
  if curl -sS --connect-timeout 2 "http://127.0.0.1:${port}/v1/models" -o "/tmp/qwen_models_${port}.json" 2>/dev/null; then
    echo "OK  http://127.0.0.1:${port}/v1/models"
    python -m json.tool "/tmp/qwen_models_${port}.json" 2>/dev/null | head -25
  else
    echo "---- http://127.0.0.1:${port}/v1/models (no response)"
  fi
done

echo
echo "=== HuggingFace Qwen checkpoints (top 15) ==="
find "${HF_HOME:-$HOME/.cache/huggingface}/hub" -maxdepth 3 -type d -iname '*qwen*' 2>/dev/null | head -15 || true

echo
echo "=== ModelScope Qwen checkpoints (if any) ==="
find "${MODELSCOPE_CACHE:-$HOME/.cache/modelscope}/hub" -maxdepth 4 -type d -iname '*qwen*' 2>/dev/null | head -15 || true

echo
echo "=== Serving backends ==="
command -v lmdeploy >/dev/null && echo "lmdeploy: $(lmdeploy --version 2>/dev/null || echo installed)" || echo "lmdeploy: not installed"
command -v vllm >/dev/null && vllm --version 2>/dev/null || echo "vllm: not installed"
