# The AuthorOS character model

Your own model, trained by you and run on your own server. This directory is the
whole pipeline: data in, trained weights out, a small server in front, and a check
of what it produces. Nothing here calls anyone else's model.

**Scope of v0: greetings and light conversation.** A character opens a conversation,
welcomes the author back, and replies in kind to a light remark ("good morning", "how
are you", "thanks", "see you tomorrow"). It does not ask the story's questions, read
answers or decide what becomes canon: the engine still does all of that.

## The decisions, and why

- **Fine-tune a small open model rather than train from scratch.** The base is
  `HuggingFaceTB/SmolLM2-135M` (Apache-2.0, 135M parameters). Training from scratch
  would need orders of magnitude more text than greetings and chat can supply, and
  would produce worse English for the same data. You still train it, the weights are
  yours, and nothing about the base's licence restricts what you do with them.
  `train.py` can also start from random weights (`--from-scratch`) to compare.
- **Small, so it runs on a modest server.** 135M parameters runs on a CPU (a second
  or two a reply) and fits easily in a few GB; a GPU is only needed for training
  larger data or a larger base.
- **Every reply is still checked, and there is still a fallback.** The model's
  output goes through the same kind of guard as before (short, plain, no invented
  name or number), and a failure falls back to the authored line. A small model of
  your own will sometimes be wrong; the floor is what makes that safe.

## What it will be good and bad at, honestly

It will be as good as its data. v0's data is public-domain fiction, which teaches
natural, conversational English and a wide range of manners, but in a nineteenth-
and early twentieth-century voice, and with no label saying which voice is which. So
v0 can reply to a greeting plausibly and briefly, and it cannot yet be told "sardonic"
or "timid" and obey. Voice control comes with voice-labelled data: lines the author
wrote for their own characters, and (with consent) lines authors accept or edit in
Companion. The format already has a `VOICE:` line for it; v0 fills it with
`unlabelled`.

## Where the data comes from, and where it must not

**Allowed here:** public-domain text (Project Gutenberg, via `prepare_gutenberg.py`),
text you wrote yourself, and anything you hold the rights to or that carries a licence
allowing commercial use. Keep a record of each source and its licence in
`data/SOURCES.md`.

**Check before using:** many popular dialogue datasets are research- or
non-commercial-only (DailyDialog, Empathetic Dialogues, Persona-Chat variants, movie
and subtitle corpora), and scraped chat is not yours to train on. **Text written by
another AI service may have terms against training a model on it:** Anthropic's
terms restrict using its outputs to build competing models, and other providers have
similar clauses. So this pipeline does not generate training text with any AI
service, and the code in this directory contains no such step. Read the terms of
whatever you use before putting its output in `data/`.

## Writing the training lines

The model gets better from lines you write, in the voice of each tone, so the format
is made for writing by hand. One plain text file per voice (or several voices in one):

```
written-by: Your Name
rights: own                 # own | public-domain | licensed
ai-assisted: no             # must be "no"

voice: sardonic
length: measured            # terse | measured | expansive

[opening]
Oh. You came. How unexpectedly punctual.

[chat]
> Good morning!
Is it? Do tell me what is good about it.
```

`[opening]`, `[returning]`, `[chat]` and `[farewell]` are the moments; `>` is the
author's line, and a reply is one line. The twelve voices are Companion's tones:
neutral, warm, gentle, earnest, dry, sardonic, blunt, formal, timid, quiet, playful,
stoic. Copy `authoring/TEMPLATE.example.md`.

The checker holds your lines to the same rules the model's replies will be held to:
short (30 words), plain (no markdown, quotation marks or digits), and no names or
titles, because a character here is not given a name. It also requires the three
header lines, so every line has a recorded author and right to use it.

```
python model/authoring.py check    model/authoring/*.md       # errors and repeats
python model/authoring.py coverage model/authoring/*.md       # voice x moment table
python model/authoring.py build    model/authoring/*.md       # writes data/train.jsonl, eval.jsonl
python model/authoring.py build --with-gutenberg model/authoring/*.md   # adds the public-domain set, unlabelled
```

A first useful fine-tune wants roughly ten openings, ten returning lines, forty chat
exchanges and ten farewells per voice (about 840 lines); `coverage` shows the gaps.
Every tenth line of each cell is held out for evaluation. Fewer lines still train;
they just constrain the voice less.

## Run it

```
python -m venv .venv && . .venv/bin/activate
pip install -r model/requirements.txt          # CPU torch is enough for v0

python model/prepare_gutenberg.py              # public-domain exchanges -> data/gutenberg_*.jsonl
python model/authoring.py build --with-gutenberg model/authoring/*.md   # -> data/train.jsonl, eval.jsonl
python model/train.py --out runs/v0            # fine-tune (add --device cuda on a GPU)
python model/eval.py runs/v0 sardonic,timid    # sample replies in each voice
python model/serve.py runs/v0 --token SECRET   # serve on your own machine
```

`serve.py` listens on `127.0.0.1:8808` by default; put your own TLS in front of it
(a reverse proxy) before exposing it, and keep the token private.

## Shrinking it (8-bit): tried, not recommended yet

`quantize.py` converts a trained model to 8-bit weights (PyTorch dynamic
quantisation) and `serve.py` serves the result unchanged. Measured on the v0 model,
on 4 CPU cores:

| | fp32 | int8 |
|---|---|---|
| file size | 538 MB | 248 MB |
| 24 tokens | 0.19 s | 0.12 s |
| same reply as fp32 (10 prompts, greedy) | | 1 of 10 |

It is smaller and faster, but it changes what the model says, and for the worse in
places (it started echoing the author's line). That is on a weak v0 model, so the
comparison is noisy, but there is no reason to accept it. fp32 is already fast enough
(0.2 to 0.45 s a reply) and 540 MB is small, so **serve fp32 for now**. If size
matters later, try half precision (a halving with little loss) or a GGUF Q8_0 export
for llama.cpp, which quantises more carefully. PyTorch's `torch.ao` quantisation is
also being retired in favour of torchao, so this script is a measurement tool, not a
dependency to build on.

## The format

One example is a short block of text; the model learns to write what follows
`CHARACTER:`.

```
VOICE: tone=unlabelled length=measured
MOMENT: chat            (opening | returning | chat | farewell)
AUTHOR: Good morning, how are you?
CHARACTER: Very well, thank you. And you?
```

Loss is computed on the reply only. `AUTHOR:` is empty for an opening.

## Not here yet

- The Dart client (`ModelClient` for your server), the settings in Companion and the
  chat guard. They come after there is a model worth calling.
- Voice-labelled data (the format and checker are here; the lines are yours to write),
  and a per-tone evaluation once there are lines to measure.
- Costs: the numbers for serving you-versus-the-user come once there is a model to
  measure.
