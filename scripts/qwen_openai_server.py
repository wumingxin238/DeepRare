#!/usr/bin/env python3
"""
OpenAI-compatible /v1/chat/completions for DeepRare local Qwen3.

Based on MedRBench scripts/server/judge/judge_server_transformers.py
+ MedRBench run_qwen_inference.py fp16 loader (A800 80GB).

  conda activate qwen3_infer
  CUDA_VISIBLE_DEVICES=1 python scripts/qwen_openai_server.py \\
      --model Qwen/Qwen3-14B --port 8000 --fp16

Then in inference_gene_qwen.sh:
  LOCAL_BASE_URL=http://127.0.0.1:8000/v1
  QWEN_MODEL=Qwen/Qwen3-14B
"""

from __future__ import annotations

import argparse
import time
import uuid
from typing import Any, Dict, List, Optional

import torch
import uvicorn
from fastapi import FastAPI
from pydantic import BaseModel, Field
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig

app = FastAPI()
_model = None
_tokenizer = None
_model_id = ""
_enable_thinking = False


class Message(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    model: str
    messages: List[Message]
    temperature: float = 0.0
    max_tokens: Optional[int] = Field(default=2048, alias="max_tokens")


def load_model(model_id: str, *, fp16: bool = True, four_bit: bool = False) -> None:
    global _model, _tokenizer, _model_id

    print(f"transformers load | torch={torch.__version__} | cuda={torch.cuda.is_available()}")
    print(f"Loading {model_id} (fp16={fp16}, 4bit={four_bit})...")

    kwargs: Dict[str, Any] = {"trust_remote_code": True, "low_cpu_mem_usage": True}
    if four_bit:
        kwargs["quantization_config"] = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_compute_dtype=torch.float16,
            bnb_4bit_use_double_quant=True,
            bnb_4bit_quant_type="nf4",
        )
        kwargs["device_map"] = "auto"
    elif fp16:
        kwargs["torch_dtype"] = torch.float16
        kwargs["device_map"] = "cuda:0"
    else:
        kwargs["torch_dtype"] = torch.float16
        kwargs["device_map"] = "auto"

    _tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)
    _model = AutoModelForCausalLM.from_pretrained(model_id, **kwargs)
    _model.eval()
    _model_id = model_id
    print("Model ready.")


def _build_prompt(messages: List[Dict[str, str]]) -> str:
    try:
        return _tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
            enable_thinking=_enable_thinking,
        )
    except TypeError:
        return _tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )


@app.get("/v1/models")
def list_models():
    return {
        "object": "list",
        "data": [{"id": _model_id, "object": "model", "owned_by": "local"}],
    }


@app.post("/v1/chat/completions")
def chat_completions(req: ChatRequest):
    if _model is None or _tokenizer is None:
        return {"error": "model not loaded"}, 503

    messages = [{"role": m.role, "content": m.content} for m in req.messages]
    prompt = _build_prompt(messages)
    inputs = _tokenizer(prompt, return_tensors="pt").to(_model.device)
    max_new = req.max_tokens or 2048
    temp = max(req.temperature, 0.0)
    gen_kwargs: Dict[str, Any] = {
        "max_new_tokens": max_new,
        "do_sample": temp > 0,
        "pad_token_id": _tokenizer.eos_token_id,
    }
    if temp > 0:
        gen_kwargs["temperature"] = temp

    t0 = time.time()
    with torch.no_grad():
        out = _model.generate(**inputs, **gen_kwargs)
    text = _tokenizer.decode(out[0][inputs["input_ids"].shape[1]:], skip_special_tokens=True)

    return {
        "id": f"chatcmpl-{uuid.uuid4().hex[:12]}",
        "object": "chat.completion",
        "created": int(t0),
        "model": req.model,
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": text.strip()},
                "finish_reason": "stop",
            }
        ],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="Qwen/Qwen3-14B")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--fp16", action="store_true", help="Full fp16 on one GPU (~28GB, A800)")
    parser.add_argument("--4bit", dest="four_bit", action="store_true", help="4-bit bitsandbytes")
    parser.add_argument(
        "--enable-thinking",
        action="store_true",
        help="Qwen3 thinking mode (MedRBench qwen3-14b-thinking)",
    )
    args = parser.parse_args()

    global _enable_thinking
    _enable_thinking = args.enable_thinking

    if not args.fp16 and not args.four_bit:
        args.fp16 = True

    load_model(args.model, fp16=args.fp16, four_bit=args.four_bit)
    print(f"OpenAI API: http://{args.host}:{args.port}/v1  model={args.model}")
    uvicorn.run(app, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()
