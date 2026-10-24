"""What a trained model says, on prompts it has not seen, with a few cheap checks.

    python model/eval.py runs/v0 [sardonic,timid,...]

The checks are deliberately simple (a reply exists, is one short line, does not just
repeat what the author said, brings in no number). The fuller guard lives in the Dart
package and runs on every reply in use; this is for comparing runs.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

from common import first_line, prompt

CASES = [
    ("opening", ""),
    ("returning", ""),
    ("chat", "Good morning!"),
    ("chat", "How are you today?"),
    ("chat", "Thank you for talking with me."),
    ("chat", "It's raining again."),
    ("chat", "I slept badly last night."),
    ("chat", "Nice to see you."),
    ("chat", "Have you eaten?"),
    ("farewell", ""),
    ("chat", "I should go now."),
    ("chat", "Good night."),
]


def say(model, tok, moment, author, voice="unlabelled", temperature=0.8, max_new=40, seed=0):
    torch.manual_seed(seed)
    ids = tok(prompt(moment, author, voice), return_tensors="pt")
    out = model.generate(
        **ids,
        max_new_tokens=max_new,
        do_sample=temperature > 0,
        temperature=max(temperature, 1e-5),
        top_p=0.9,
        repetition_penalty=1.1,
        pad_token_id=tok.eos_token_id,
    )
    return first_line(tok.decode(out[0, ids["input_ids"].shape[1] :], skip_special_tokens=True))


def checks(author: str, reply: str) -> list[str]:
    bad = []
    if not reply:
        bad.append("empty")
    if len(reply.split()) > 30:
        bad.append("long")
    if author and reply.lower().strip(".!? ") == author.lower().strip(".!? "):
        bad.append("echo")
    if re.search(r"\d", reply):
        bad.append("number")
    return bad


def main() -> None:
    run = Path(sys.argv[1])
    voices = sys.argv[2].split(",") if len(sys.argv) > 2 else ["unlabelled"]
    tok = AutoTokenizer.from_pretrained(run)
    model = AutoModelForCausalLM.from_pretrained(run).eval()
    failed = 0
    total = 0
    for voice in voices:
        print(f"\n== {voice}")
        for moment, author in CASES:
            reply = say(model, tok, moment, author, voice)
            bad = checks(author, reply)
            failed += bool(bad)
            total += 1
            print(f"[{moment}] {author or '-':38} -> {reply}" + (f"   !! {','.join(bad)}" if bad else ""))
    print(f"\n{total - failed}/{total} pass the simple checks")


if __name__ == "__main__":
    main()
