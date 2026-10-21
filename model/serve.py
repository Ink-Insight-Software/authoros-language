"""Serve a trained model over HTTP, from your own machine.

    python model/serve.py runs/v0 --token SECRET [--host 127.0.0.1 --port 8808]

POST /v1/say   Authorization: Bearer SECRET
  {"moment": "chat", "author": "Good morning!", "voice": "unlabelled",
   "temperature": 0.8, "max_new_tokens": 40}
  -> {"text": "...", "model": "runs/v0"}

GET /healthz -> {"ok": true}

Standard library only (plus torch and transformers). It listens on localhost by
default; put your own TLS and rate limit in front (a reverse proxy) before it is
reachable from anywhere else. Nothing is logged but the time and the status: no
prompt or reply is written anywhere.
"""

from __future__ import annotations

import argparse
import hmac
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

from common import MOMENTS, first_line, prompt

MAX_BODY = 4096
MAX_AUTHOR_CHARS = 600


def make_handler(model, tok, token: str, name: str):
    lock = threading.Lock()  # one generation at a time: the model is not re-entrant

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):  # status only, never content
            print(f"{self.log_date_time_string()} {self.command} {self.path} {args[1] if len(args) > 1 else ''}")

        def _send(self, code: int, body: dict) -> None:
            data = json.dumps(body).encode()
            self.send_response(code)
            self.send_header("content-type", "application/json")
            self.send_header("content-length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            self._send(200, {"ok": True}) if self.path == "/healthz" else self._send(404, {"error": "not found"})

        def do_POST(self):
            if self.path != "/v1/say":
                return self._send(404, {"error": "not found"})
            given = self.headers.get("authorization", "")
            if not hmac.compare_digest(given.encode(), f"Bearer {token}".encode()):
                return self._send(401, {"error": "unauthorised"})
            try:
                n = int(self.headers.get("content-length", "0"))
                if n <= 0 or n > MAX_BODY:
                    return self._send(413, {"error": "body size"})
                req = json.loads(self.rfile.read(n))
                moment = req.get("moment", "chat")
                if moment not in MOMENTS:
                    return self._send(400, {"error": "unknown moment"})
                author = str(req.get("author", ""))[:MAX_AUTHOR_CHARS]
                voice = str(req.get("voice", "unlabelled"))[:40]
                temp = min(max(float(req.get("temperature", 0.8)), 0.0), 1.5)
                max_new = min(max(int(req.get("max_new_tokens", 40)), 1), 80)
            except (ValueError, TypeError, json.JSONDecodeError):
                return self._send(400, {"error": "bad request"})
            with lock, torch.no_grad():
                ids = tok(prompt(moment, author, voice), return_tensors="pt")
                out = model.generate(
                    **ids,
                    max_new_tokens=max_new,
                    do_sample=temp > 0,
                    temperature=max(temp, 1e-5),
                    top_p=0.9,
                    repetition_penalty=1.1,
                    pad_token_id=tok.eos_token_id,
                )
            text = first_line(tok.decode(out[0, ids["input_ids"].shape[1] :], skip_special_tokens=True))
            self._send(200, {"text": text, "model": name})

    return Handler


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("run")
    ap.add_argument("--token", required=True)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8808)
    a = ap.parse_args()
    if len(a.token) < 12:
        raise SystemExit("use a longer token (12+ characters)")
    run = Path(a.run)
    tok = AutoTokenizer.from_pretrained(run)
    model = AutoModelForCausalLM.from_pretrained(run).eval()
    server = ThreadingHTTPServer((a.host, a.port), make_handler(model, tok, a.token, str(run)))
    print(f"serving {run} on http://{a.host}:{a.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
