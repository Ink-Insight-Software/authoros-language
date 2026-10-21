"""Fine-tune a small open model on data/train.jsonl, so characters can greet and chat.

    python model/train.py --out runs/v0                 # CPU is fine for v0
    python model/train.py --out runs/v0 --device cuda   # on a GPU
    python model/train.py --out runs/scratch --from-scratch   # random start, to compare

Loss is on the reply only. Writes the model, tokenizer and a train log to --out.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import time
from pathlib import Path

import torch
from transformers import AutoConfig, AutoModelForCausalLM, AutoTokenizer

from common import example

HERE = Path(__file__).parent
BASE = "HuggingFaceTB/SmolLM2-135M"


def load(path: Path) -> list[dict]:
    return [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]


def encode(tok, row: dict, max_len: int):
    p, r = example(row)
    p_ids = tok(p, add_special_tokens=False)["input_ids"]
    r_ids = tok(r, add_special_tokens=False)["input_ids"] + [tok.eos_token_id]
    ids = (p_ids + r_ids)[:max_len]
    labels = ([-100] * len(p_ids) + r_ids)[:max_len]
    return ids, labels


def batches(items, size, rng, pad_id):
    order = list(range(len(items)))
    rng.shuffle(order)
    for i in range(0, len(order), size):
        chunk = [items[j] for j in order[i : i + size]]
        n = max(len(ids) for ids, _ in chunk)
        ids = torch.full((len(chunk), n), pad_id, dtype=torch.long)
        lab = torch.full((len(chunk), n), -100, dtype=torch.long)
        att = torch.zeros((len(chunk), n), dtype=torch.long)
        for k, (a, b) in enumerate(chunk):
            ids[k, : len(a)] = torch.tensor(a)
            lab[k, : len(b)] = torch.tensor(b)
            att[k, : len(a)] = 1
        yield ids, lab, att


@torch.no_grad()
def evaluate(model, items, device, pad_id, bs=16):
    model.eval()
    total, count = 0.0, 0
    for ids, lab, att in batches(items, bs, random.Random(0), pad_id):
        out = model(input_ids=ids.to(device), attention_mask=att.to(device))
        logits = out.logits[:, :-1]
        target = lab[:, 1:].to(device)
        loss = torch.nn.functional.cross_entropy(
            logits.reshape(-1, logits.size(-1)), target.reshape(-1), ignore_index=-100, reduction="sum"
        )
        total += loss.item()
        count += (target != -100).sum().item()
    model.train()
    return total / max(count, 1)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--base", default=BASE)
    ap.add_argument("--from-scratch", action="store_true")
    ap.add_argument("--data", default=str(HERE / "data"))
    ap.add_argument("--epochs", type=int, default=3)
    ap.add_argument("--batch", type=int, default=8)
    ap.add_argument("--lr", type=float, default=5e-5)
    ap.add_argument("--max-len", type=int, default=96)
    ap.add_argument("--device", default="cpu")
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()

    torch.manual_seed(a.seed)
    rng = random.Random(a.seed)
    tok = AutoTokenizer.from_pretrained(a.base)
    if tok.pad_token_id is None:
        tok.pad_token = tok.eos_token
    if a.from_scratch:
        model = AutoModelForCausalLM.from_config(AutoConfig.from_pretrained(a.base))
    else:
        model = AutoModelForCausalLM.from_pretrained(a.base, dtype=torch.float32)
    model.to(a.device).train()
    print(f"{sum(p.numel() for p in model.parameters()) / 1e6:.0f}M parameters, device {a.device}")

    data = Path(a.data)
    train = [encode(tok, r, a.max_len) for r in load(data / "train.jsonl")]
    held = [encode(tok, r, a.max_len) for r in load(data / "eval.jsonl")]
    print(f"{len(train)} train, {len(held)} held out")

    opt = torch.optim.AdamW(model.parameters(), lr=a.lr, weight_decay=0.01)
    steps = a.epochs * math.ceil(len(train) / a.batch)
    sched = torch.optim.lr_scheduler.LambdaLR(
        opt, lambda s: min(1.0, (s + 1) / max(1, steps // 10)) * max(0.05, 1 - s / steps)
    )
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    log = []
    step, t0 = 0, time.time()
    before = evaluate(model, held, a.device, tok.pad_token_id) if held else float("nan")
    print(f"held-out loss before training: {before:.3f}")
    for epoch in range(a.epochs):
        run, n = 0.0, 0
        for ids, lab, att in batches(train, a.batch, rng, tok.pad_token_id):
            out_ = model(input_ids=ids.to(a.device), attention_mask=att.to(a.device), labels=lab.to(a.device))
            out_.loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            opt.step()
            sched.step()
            opt.zero_grad(set_to_none=True)
            run += out_.loss.item()
            n += 1
            step += 1
            if step % 10 == 0:
                print(f"  step {step}/{steps}  loss {run / n:.3f}  {time.time() - t0:.0f}s")
        held_loss = evaluate(model, held, a.device, tok.pad_token_id) if held else float("nan")
        log.append({"epoch": epoch + 1, "train_loss": run / max(n, 1), "held_out_loss": held_loss})
        print(f"epoch {epoch + 1}: train {run / max(n, 1):.3f}  held-out {held_loss:.3f}")
    model.save_pretrained(out)
    tok.save_pretrained(out)
    (out / "train_log.json").write_text(
        json.dumps({"base": None if a.from_scratch else a.base, "args": vars(a), "before": before, "epochs": log}, indent=2)
    )
    print(f"saved to {out}")


if __name__ == "__main__":
    main()
