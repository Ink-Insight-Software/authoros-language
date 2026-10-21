"""Writing the model's training lines, checking them, and turning them into data.

You write a plain text file per voice (or several voices in one). The checker holds
your lines to the same rules the Dart guard holds a reply to, so what you write is
what the model will be allowed to say.

    python model/authoring.py check    model/authoring/*.md
    python model/authoring.py coverage model/authoring/*.md
    python model/authoring.py build    model/authoring/*.md [--with-gutenberg]

File format (see authoring/TEMPLATE.example.md):

    written-by: Your Name
    rights: own            # own | public-domain | licensed
    ai-assisted: no        # must be "no": see README, "Where the data comes from"

    voice: sardonic
    length: measured       # terse | measured | expansive; default measured

    [opening]
    A line the character opens a conversation with.

    [chat]
    > What the author says
    The character's reply, on one line.

`#` starts a comment. `>` marks the author's line; `[opening]` and `[returning]` have
none. Files named `*.example.md` are format illustrations and are never built.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from common import LENGTHS, MOMENTS, TONES

HERE = Path(__file__).parent
DATA = HERE / "data"

RIGHTS = ("own", "public-domain", "licensed")
NO_AUTHOR_LINE = ("opening", "returning")
MAX_REPLY_WORDS = 30
MAX_AUTHOR_WORDS = 40

# The same ideas as the Dart DeliveryGuard: plain, short, no name, no number.
MARKUP = re.compile(r"[*#`_>|\[\]{}<>\\]|^\s*[-•]\s")
DIGIT = re.compile(r"\d")
TITLES = r"Mr|Mrs|Miss|Ms|Dr|Sir|Madam|Lady|Lord"
NAMEISH = re.compile(rf"\b(?:{TITLES})\b\.?")


@dataclass
class Row:
    voice: str
    length: str
    moment: str
    author: str
    reply: str
    file: str
    line: int
    written_by: str = ""
    rights: str = ""


@dataclass
class Problems:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def error(self, file: str, line: int, msg: str) -> None:
        self.errors.append(f"{file}:{line}: {msg}")

    def warn(self, file: str, line: int, msg: str) -> None:
        self.warnings.append(f"{file}:{line}: {msg}")


def mid_sentence_capitals(text: str) -> list[str]:
    """Capitalised words that do not begin a sentence (so, a name), apart from 'I'."""
    out = []
    for m in re.finditer(r"[A-Za-z][A-Za-z'’-]*", text):
        w = m.group(0)
        if w in ("I",) or w.startswith(("I'", "I’")) or w[0].islower():
            continue
        head = text[: m.start()].rstrip()
        if not head or re.search(r"[.!?…]$", head) or head.endswith(("—", "-", '"', "“")):
            continue
        out.append(w)
    return out


def check_reply(reply: str, what: str) -> list[str]:
    bad = []
    if not reply.strip():
        bad.append(f"{what} is empty")
        return bad
    words = len(reply.split())
    limit = MAX_REPLY_WORDS if what == "reply" else MAX_AUTHOR_WORDS
    if words > limit:
        bad.append(f"{what} is {words} words; the limit is {limit}")
    if MARKUP.search(reply):
        bad.append(f"{what} has markup or a list marker")
    if DIGIT.search(reply):
        bad.append(f"{what} has a digit; write numbers as words or leave them out")
    if NAMEISH.search(reply) or mid_sentence_capitals(reply):
        bad.append(
            f"{what} seems to name someone or somewhere "
            f"({', '.join(mid_sentence_capitals(reply)) or 'a title'}); "
            "characters are not given names here"
        )
    if reply.count('"') or "“" in reply or "”" in reply:
        bad.append(f"{what} has quotation marks")
    return bad


def parse(path: Path, problems: Problems) -> list[Row]:
    rows: list[Row] = []
    name = str(path)
    header: dict[str, str] = {}
    voice, length, moment = "", "measured", ""
    pending_author: tuple[str, int] | None = None
    in_voice_block = False

    def flush_dangling(line_no: int) -> None:
        nonlocal pending_author
        if pending_author:
            problems.error(name, pending_author[1], "an author line with no reply after it")
            pending_author = None

    for i, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("#", 1)[0].rstrip() if not raw.lstrip().startswith(">") else raw.rstrip()
        if raw.lstrip().startswith("#"):
            continue
        if not line.strip():
            continue
        m = re.match(r"^([a-z][a-z-]*):\s*(.*)$", line.strip())
        if m and m.group(1) in (
            "written-by", "rights", "ai-assisted", "voice", "length",
        ):
            key, val = m.group(1), m.group(2).strip()
            flush_dangling(i)
            if key == "voice":
                voice, length, moment, in_voice_block = val, "measured", "", True
                if val not in TONES:
                    problems.error(name, i, f"unknown voice {val!r}; one of: {', '.join(TONES)}")
            elif key == "length":
                length = val
                if val not in LENGTHS:
                    problems.error(name, i, f"unknown length {val!r}; one of: {', '.join(LENGTHS)}")
            else:
                header[key] = val
            continue
        m = re.match(r"^\[([a-z]+)\]$", line.strip())
        if m:
            flush_dangling(i)
            moment = m.group(1)
            if moment not in MOMENTS:
                problems.error(name, i, f"unknown moment [{moment}]; one of: {', '.join(MOMENTS)}")
            continue
        if not in_voice_block:
            problems.error(name, i, "a line before any `voice:`")
            continue
        if not moment:
            problems.error(name, i, "a line before any [moment]")
            continue
        text = line.strip()
        if text.startswith(">"):
            flush_dangling(i)
            if moment in NO_AUTHOR_LINE:
                problems.error(name, i, f"[{moment}] has no author line")
                continue
            pending_author = (text[1:].strip(), i)
            for b in check_reply(pending_author[0], "author line"):
                problems.error(name, i, b)
            continue
        # A reply.
        author = ""
        if moment not in NO_AUTHOR_LINE:
            if pending_author is None:
                problems.error(name, i, f"[{moment}] reply with no `>` author line before it")
                continue
            author = pending_author[0]
            pending_author = None
        elif pending_author:
            pending_author = None
        for b in check_reply(text, "reply"):
            problems.error(name, i, b)
        if moment in MOMENTS and voice in TONES and length in LENGTHS:
            rows.append(
                Row(voice, length, moment, author, text, name, i,
                    header.get("written-by", ""), header.get("rights", ""))
            )
    flush_dangling(0)

    if not header.get("written-by"):
        problems.error(name, 1, "no `written-by:` header")
    if header.get("rights") not in RIGHTS:
        problems.error(name, 1, f"`rights:` must be one of {', '.join(RIGHTS)}")
    if header.get("ai-assisted") != "no":
        problems.error(
            name, 1,
            "`ai-assisted: no` is required: lines written by an AI service are not "
            "used as training data (README, \"Where the data comes from\")",
        )
    return rows


def load(paths: list[str]) -> tuple[list[Row], Problems]:
    problems = Problems()
    rows: list[Row] = []
    for p in paths:
        path = Path(p)
        if path.name.endswith(".example.md"):
            continue
        rows.extend(parse(path, problems))
    seen: dict[tuple, str] = {}
    for r in rows:
        key = (r.voice, r.moment, r.author.lower(), r.reply.lower())
        if key in seen:
            problems.warn(r.file, r.line, f"repeats {seen[key]}")
        else:
            seen[key] = f"{Path(r.file).name}:{r.line}"
    return rows, problems


# What a first useful fine-tune wants per voice. Chat is the broadest.
TARGETS = {"opening": 10, "returning": 10, "chat": 40, "farewell": 10}


def coverage(rows: list[Row]) -> str:
    cell: Counter = Counter((r.voice, r.moment) for r in rows)
    lines = ["voice       " + "".join(f"{m:>11}" for m in MOMENTS) + "     total"]
    gaps = 0
    for tone in TONES:
        cols, total = [], 0
        for m in MOMENTS:
            n = cell[(tone, m)]
            total += n
            short = n < TARGETS[m]
            gaps += short
            cols.append(f"{n:>5}/{TARGETS[m]:<3}{'*' if short else ' '}  ")
        lines.append(f"{tone:<12}" + "".join(c[:11].rjust(11) for c in cols) + f"{total:>10}")
    lines.append("")
    lines.append(f"{len(rows)} lines; {gaps} of {len(TONES) * len(MOMENTS)} cells under target (*)")
    return "\n".join(lines)


def split(rows: list[Row]) -> tuple[list[Row], list[Row]]:
    """Every tenth line of each (voice, moment) goes to evaluation, once a cell has
    at least five, so evaluation covers each voice and cannot be learned by heart."""
    cells: dict[tuple, list[Row]] = defaultdict(list)
    for r in rows:
        cells[(r.voice, r.moment)].append(r)
    train, held = [], []
    for rs in cells.values():
        rs.sort(key=lambda r: (r.file, r.line))
        for i, r in enumerate(rs):
            (held if len(rs) >= 5 and i % 10 == 9 else train).append(r)
    return train, held


def to_json(r: Row) -> dict:
    return {
        "voice": r.voice, "length": r.length, "moment": r.moment,
        "author": r.author, "reply": r.reply,
        "source": "authored", "rights": r.rights, "written_by": r.written_by,
    }


def build(rows: list[Row], with_gutenberg: bool) -> None:
    DATA.mkdir(parents=True, exist_ok=True)
    train, held = split(rows)
    out_train = [to_json(r) for r in train]
    out_held = [to_json(r) for r in held]
    if with_gutenberg:
        for name, sink in (("train", out_train), ("eval", out_held)):
            path = DATA / f"gutenberg_{name}.jsonl"
            if not path.exists():
                sys.exit(f"{path} is missing: run prepare_gutenberg.py first")
            for l in path.read_text(encoding="utf-8").splitlines():
                if l.strip():
                    sink.append({**json.loads(l), "length": "measured", "source": "gutenberg"})
    for name, data in (("train", out_train), ("eval", out_held)):
        with open(DATA / f"{name}.jsonl", "w", encoding="utf-8") as f:
            for r in data:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"wrote train {len(out_train)}, eval {len(out_held)} to {DATA}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["check", "coverage", "build"])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--with-gutenberg", action="store_true")
    a = ap.parse_args()
    if not a.files and not (a.command == "build" and a.with_gutenberg):
        ap.error("give at least one file")
    rows, problems = load(a.files)
    for w in problems.warnings:
        print("warning:", w)
    for e in problems.errors:
        print("error:  ", e)
    if a.command == "check":
        print(f"{len(rows)} lines, {len(problems.errors)} errors, {len(problems.warnings)} warnings")
        return 1 if problems.errors else 0
    if problems.errors:
        print("fix the errors first")
        return 1
    if a.command == "coverage":
        print(coverage(rows))
        return 0
    build(rows, a.with_gutenberg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
