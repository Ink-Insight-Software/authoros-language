"""Shrink a trained model to 8-bit weights for cheaper CPU serving.

    python model/quantize.py runs/v0 runs/v0-int8
    python model/serve.py runs/v0-int8 --token SECRET        # serves it, unchanged

Dynamic int8 quantisation of the linear layers (PyTorch). The output directory holds
the tokenizer and config, the int8 weights as `int8.pt` (tensors only: it loads with
`weights_only=True`, so a downloaded copy cannot run code), and a note of how much it
shrank and how close it stays to the original. Always compare replies before using it.
"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import torch
from transformers import AutoConfig, AutoModelForCausalLM, AutoTokenizer

from common import prompt

PROBES = [
    ("chat", "Good morning!"), ("chat", "How are you today?"), ("chat", "I slept badly last night."),
    ("opening", ""), ("farewell", ""), ("chat", "Thank you."),
]


def quantized(model):
    return torch.ao.quantization.quantize_dynamic(model, {torch.nn.Linear}, dtype=torch.qint8)


def load_int8(run: Path):
    """The int8 model saved by this script."""
    cfg = AutoConfig.from_pretrained(run)
    base = AutoModelForCausalLM.from_config(cfg).eval()
    q = quantized(base)
    q.load_state_dict(torch.load(run / "int8.pt", weights_only=True))
    return q.eval()


def logits_for(model, tok, moment, author):
    ids = tok(prompt(moment, author), return_tensors="pt")
    with torch.no_grad():
        return model(**ids).logits[0, -1]


def main() -> None:
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    tok = AutoTokenizer.from_pretrained(src)
    fp = AutoModelForCausalLM.from_pretrained(src, dtype=torch.float32).eval()
    q = quantized(AutoModelForCausalLM.from_pretrained(src, dtype=torch.float32).eval())
    dst.mkdir(parents=True, exist_ok=True)
    torch.save(q.state_dict(), dst / "int8.pt")
    AutoConfig.from_pretrained(src).save_pretrained(dst)
    tok.save_pretrained(dst)

    agree, kl = 0, 0.0
    for moment, author in PROBES:
        a, b = logits_for(fp, tok, moment, author), logits_for(q, tok, moment, author)
        agree += int(a.argmax() == b.argmax())
        kl += torch.nn.functional.kl_div(
            b.log_softmax(-1), a.softmax(-1), reduction="sum"
        ).item()
    times = {}
    for name, m in (("fp32", fp), ("int8", q)):
        ids = tok(prompt("chat", "Good morning!"), return_tensors="pt")
        with torch.no_grad():
            m.generate(**ids, max_new_tokens=8, pad_token_id=tok.eos_token_id)  # warm up
            t = time.time()
            for _ in range(5):
                m.generate(**ids, max_new_tokens=24, do_sample=False, pad_token_id=tok.eos_token_id)
        times[name] = (time.time() - t) / 5
    size = lambda p: sum(f.stat().st_size for f in Path(p).glob("*") if f.name.endswith((".safetensors", ".pt")))
    report = {
        "size_mb": {"fp32": size(src) / 1e6, "int8": size(dst) / 1e6},
        "seconds_for_24_tokens": times,
        "next_token_agreement": f"{agree}/{len(PROBES)}",
        "mean_kl_from_fp32": kl / len(PROBES),
    }
    (dst / "quantize_report.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
