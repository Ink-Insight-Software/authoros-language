"""Public-domain conversational exchanges, for the character model's first data.

Downloads a short list of public-domain novels from Project Gutenberg, finds runs of
quoted speech, and writes (author line -> character reply) pairs, plus opening and
farewell lines, as JSONL for train.py. Text only from sources whose licence allows
it: record each in data/SOURCES.md.

    python model/prepare_gutenberg.py [--limit-books N] [--max-words 22]

Public domain in the United States; Gutenberg asks that bulk users fetch politely, so
files are cached in data/raw and fetched once, one at a time.
"""

from __future__ import annotations

import argparse
import json
import random
import re
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
RAW = HERE / "data" / "raw"
OUT = HERE / "data"

# Novels and plays with plenty of dialogue, across manners: dry, warm, earnest,
# comic, formal. (id, short title)
BOOKS = [
    (1342, "Pride and Prejudice"),
    (158, "Emma"),
    (105, "Persuasion"),
    (141, "Mansfield Park"),
    (161, "Sense and Sensibility"),
    (1260, "Jane Eyre"),
    (514, "Little Women"),
    (45, "Anne of Green Gables"),
    (74, "The Adventures of Tom Sawyer"),
    (76, "Adventures of Huckleberry Finn"),
    (11, "Alice's Adventures in Wonderland"),
    (289, "The Wind in the Willows"),
    (1661, "The Adventures of Sherlock Holmes"),
    (308, "Three Men in a Boat"),
    (174, "The Picture of Dorian Gray"),
    (394, "Cranford"),
    (730, "Oliver Twist"),
    (98, "A Tale of Two Cities"),
    (1400, "Great Expectations"),
    (2591, "Grimms' Fairy Tales"),
    (8164, "My Man Jeeves"),
    (829, "Gulliver's Travels"),
    (967, "Nicholas Nickleby"),
    (766, "David Copperfield"),
]

GREETING = re.compile(
    r"^(?:good\s+(?:morning|afternoon|evening|day|night)|hello|hallo|hullo|hi\b|"
    r"how\s+do\s+you\s+do|how\s+are\s+you|how\s+d'ye\s+do|welcome|"
    r"i\s+am\s+(?:so\s+)?(?:glad|pleased)\s+to\s+(?:see|meet)|"
    r"(?:so\s+)?(?:glad|pleased)\s+to\s+(?:see|meet)|well,?\s+here\s+you\s+are)",
    re.I,
)
FAREWELL = re.compile(
    r"^(?:good-?\s*bye|farewell|good\s+night|good\s+day|see\s+you|until\s+(?:then|"
    r"tomorrow)|i\s+must\s+(?:go|be\s+going)|take\s+care)",
    re.I,
)
LIGHT = re.compile(
    r"\b(?:thank\s+you|thanks|please|sorry|pardon|nice|lovely|weather|tea|breakfast|"
    r"supper|dinner|sleep|slept|well|fine|tired|hungry|kind|glad|pleased|welcome|"
    r"morning|evening|afternoon|today|tomorrow|tonight)\b",
    re.I,
)


def fetch(book_id: int) -> str | None:
    RAW.mkdir(parents=True, exist_ok=True)
    path = RAW / f"pg{book_id}.txt"
    if path.exists():
        return path.read_text(encoding="utf-8", errors="replace")
    for url in (
        f"https://www.gutenberg.org/cache/epub/{book_id}/pg{book_id}.txt",
        f"https://www.gutenberg.org/files/{book_id}/{book_id}-0.txt",
    ):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "authoros-model/0.1"})
            with urllib.request.urlopen(req, timeout=30) as r:
                text = r.read().decode("utf-8", errors="replace")
            path.write_text(text, encoding="utf-8")
            time.sleep(1.0)
            return text
        except Exception as e:  # noqa: BLE001 - report and try the next url
            print(f"  {url}: {e}")
    return None


def body(text: str) -> str:
    start = re.search(r"\*\*\* ?START OF (?:THE|THIS) PROJECT GUTENBERG.*?\*\*\*", text, re.S)
    end = re.search(r"\*\*\* ?END OF (?:THE|THIS) PROJECT GUTENBERG", text)
    return text[start.end() : end.start() if end else None] if start else text


def paragraphs(text: str) -> list[str]:
    text = text.replace("\r\n", "\n")
    text = (
        text.replace("“", '"').replace("”", '"')
        .replace("‘", "'").replace("’", "'")
        .replace("_", "")
    )
    return [re.sub(r"\s+", " ", p).strip() for p in re.split(r"\n\s*\n", text) if p.strip()]


def speech(par: str) -> str | None:
    """The spoken words of a paragraph that is mostly one speaker's speech."""
    parts = re.findall(r'"([^"]+)"', par)
    if not parts:
        return None
    said = " ".join(p.strip() for p in parts)
    # Mostly speech, not narration with a quoted word in it.
    if len(said) < 0.5 * len(par):
        return None
    return said


NAME = re.compile(
    r"(?<![.!?]\s)(?<!^)\b[A-Z][a-z]{2,}\b|\b(?:Mr|Mrs|Miss|Messrs|Dr|Sir|Madam|Lady|Lord|Monsieur|Colonel|Captain)\b\.?"
)
BAD = re.compile(r"[\[\]{}<>*#@/\\|]|\d")


def clean(line: str, max_words: int) -> str | None:
    line = line.strip().strip('"').strip()
    line = re.sub(r"\s+([,.;:!?])", r"\1", line)
    n = len(line.split())
    if n < 1 or n > max_words or BAD.search(line):
        return None
    if not re.search(r"[A-Za-z]", line) or line.count("--") > 1:
        return None
    return line


def has_name(line: str) -> bool:
    return bool(NAME.search(line))


def build(max_words: int, limit_books: int | None, seed: int) -> dict[str, list[dict]]:
    rng = random.Random(seed)
    sets: dict[str, list[dict]] = {"opening": [], "chat": [], "farewell": []}
    seen: set[str] = set()
    books = BOOKS[:limit_books] if limit_books else BOOKS
    for book_id, title in books:
        print(f"{title} ({book_id})")
        raw = fetch(book_id)
        if raw is None:
            print("  skipped")
            continue
        pars = paragraphs(body(raw))
        spoken = [speech(p) for p in pars]
        for i, said in enumerate(spoken):
            if not said:
                continue
            first = clean(said.split('"')[0] if '"' in said else said, max_words)
            line = clean(said, max_words)
            if line is None:
                continue
            # A greeting, on its own, is an opening; a farewell, a farewell.
            if GREETING.match(line) and not has_name(line) and line not in seen:
                seen.add(line)
                sets["opening"].append({"moment": "opening", "author": "", "reply": line, "book": book_id})
            if FAREWELL.match(line) and not has_name(line) and line not in seen:
                seen.add(line)
                sets["farewell"].append({"moment": "farewell", "author": "", "reply": line, "book": book_id})
            # A light remark and the reply that follows it in the next paragraph.
            nxt = spoken[i + 1] if i + 1 < len(spoken) else None
            if not nxt or not (GREETING.match(line) or FAREWELL.match(line) or LIGHT.search(line)):
                continue
            reply = clean(nxt, max_words)
            if reply is None or has_name(line) or has_name(reply):
                continue
            key = f"{line}||{reply}"
            if key in seen:
                continue
            seen.add(key)
            sets["chat"].append({"moment": "chat", "author": line, "reply": reply, "book": book_id})
        print(f"  opening {len(sets['opening'])}  chat {len(sets['chat'])}  farewell {len(sets['farewell'])}")
    for rows in sets.values():
        rng.shuffle(rows)
    return sets


def write(sets: dict[str, list[dict]], eval_fraction: float, seed: int) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(seed)
    rows = [r for rs in sets.values() for r in rs]
    rng.shuffle(rows)
    # Hold out whole books' worth by hash of the reply so near-duplicates stay together.
    train, held = [], []
    for r in rows:
        (held if (hash(r["reply"]) % 1000) / 1000 < eval_fraction else train).append(r)
    for name, data in (("train", train), ("eval", held)):
        with open(OUT / f"{name}.jsonl", "w", encoding="utf-8") as f:
            for r in data:
                f.write(json.dumps({**r, "voice": "unlabelled"}, ensure_ascii=False) + "\n")
    print(f"train {len(train)}  eval {len(held)}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--max-words", type=int, default=22)
    ap.add_argument("--limit-books", type=int)
    ap.add_argument("--eval-fraction", type=float, default=0.05)
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()
    import os

    os.environ.setdefault("PYTHONHASHSEED", "0")
    write(build(a.max_words, a.limit_books, a.seed), a.eval_fraction, a.seed)
