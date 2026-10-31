"""Builds dev.jsonl and heldout.jsonl from the example files.

    python3 -I corpus/story_v1/build.py          # write the files
    python3 -I corpus/story_v1/build.py --check  # fail if the files are out of date

Every character offset is computed here from the stored text, by walking the tokens in
order; none is typed by hand, and a token that is not in the text where it should be
stops the build. See docs/story-grounding/schema.md for the record format.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))

from dev_examples import DEV  # noqa: E402
from examples_common import ENTITIES  # noqa: E402
from heldout_examples import HELDOUT  # noqa: E402

SCHEMA = "story-grounding/1"
UPOS = {"NOUN", "PROPN", "VERB", "ADJ", "ADV", "PRON", "DET", "ADP", "AUX", "CCONJ", "SCONJ",
        "PART", "NUM", "INTJ", "PUNCT"}
ROLES = {"SUBJECT", "ACTION", "OBJECT", "ATTRIBUTE", "LOCATION", "TIME", "MANNER", "CAUSE",
         "PURPOSE", "RECIPIENT", "SOURCE"}
ENTITY_TYPES = {"char": "CHARACTER", "place": "PLACE", "item": "ITEM", "group": "GROUP",
                "time": "TIME", "event": "EVENT"}
TOKEN = re.compile(
    r"^(?P<surf>.+?)/(?P<pos>[A-Z]+)(?:=(?P<lemma>[^@#\s]+))?(?:@(?P<role>[A-Z_]+))?(?:#(?P<ent>[a-z_]+))?$"
)


def entity_type(entity_id: str) -> str:
    prefix = entity_id.split("_", 1)[0]
    if prefix not in ENTITY_TYPES:
        raise ValueError(f"entity id {entity_id!r} has no known type prefix")
    return ENTITY_TYPES[prefix]


def tokens(source_id: str, text: str, compact: str) -> list[dict]:
    out, cursor = [], 0
    for piece in compact.split():
        m = TOKEN.match(piece)
        if not m:
            raise ValueError(f"{source_id}: cannot read token {piece!r}")
        surf, pos = m["surf"], m["pos"]
        if pos not in UPOS:
            raise ValueError(f"{source_id}: unknown POS {pos!r} in {piece!r}")
        if m["role"] and m["role"] not in ROLES:
            raise ValueError(f"{source_id}: unknown role {m['role']!r} in {piece!r}")
        while cursor < len(text) and text[cursor].isspace():
            cursor += 1
        if not text.startswith(surf, cursor):
            raise ValueError(
                f"{source_id}: token {surf!r} is not at offset {cursor} of {text!r} "
                f"(found {text[cursor:cursor + len(surf)]!r})"
            )
        t = {
            "text": surf, "start": cursor, "end": cursor + len(surf), "pos": pos,
            "lemma": m["lemma"] or (surf if pos == "PROPN" else surf.lower()),
        }
        if m["role"]:
            t["role"] = m["role"]
        if m["ent"]:
            t["entity_id"] = m["ent"]
            t["entity_type"] = entity_type(m["ent"])
        cursor += len(surf)
        out.append(t)
    if text[cursor:].strip():
        raise ValueError(f"{source_id}: text left over after the last token: {text[cursor:]!r}")
    return out


def source_record(s: dict) -> dict:
    facts = []
    for n, f in enumerate(s["facts"], 1):
        f = dict(f)
        f["fact_id"] = f"{s['source_id']}_f{n}"
        f["evidence_span"] = [0, len(s["text"])]
        facts.append(f)
    return {
        "source_id": s["source_id"], "text": s["text"],
        "annotations": {"tokens": tokens(s["source_id"], s["text"], s["tokens"]), "facts": facts},
    }


def record(ex: dict, split: str) -> dict:
    sources = [source_record(s) for s in ex["sources"]]
    ids = [s["source_id"] for s in sources]
    q = ex["query"]
    if q:
        for e in q["expected"]["evidence_ids"]:
            if e not in ids:
                raise ValueError(f"{ex['id']}: evidence {e!r} is not one of {ids}")
    return {
        "schema_version": SCHEMA,
        "record_id": ex["id"],
        "split": split,
        "task": "question_to_story_fact" if q else "tagging",
        "project_id": "demo_project",
        "project_entities": ENTITIES,
        "sources": sources,
        "query": q["query"] if q else None,
        "expected": q["expected"] if q else None,
    }


def build() -> dict[str, str]:
    ids = [e["id"] for e in DEV] + [e["id"] for e in HELDOUT]
    dupes = {i for i in ids if ids.count(i) > 1}
    if dupes:
        raise ValueError(f"duplicate record ids: {sorted(dupes)}")
    out = {}
    for name, examples in (("dev", DEV), ("heldout", HELDOUT)):
        out[f"{name}.jsonl"] = "".join(
            json.dumps(record(e, name), ensure_ascii=False, sort_keys=True) + "\n" for e in examples
        )
    manifest = {
        "schema_version": SCHEMA,
        "files": {
            n: {"records": t.count("\n"), "sha256": hashlib.sha256(t.encode()).hexdigest()}
            for n, t in out.items()
        },
    }
    out["MANIFEST.json"] = json.dumps(manifest, indent=2) + "\n"
    return out


if __name__ == "__main__":
    files = build()
    if "--check" in sys.argv:
        stale = [n for n, t in files.items() if not (HERE / n).exists() or (HERE / n).read_text() != t]
        if stale:
            sys.exit(f"out of date: {', '.join(stale)}; run build.py")
        print("corpus files are up to date")
    else:
        for n, t in files.items():
            (HERE / n).write_text(t)
        m = json.loads(files["MANIFEST.json"])["files"]
        print(", ".join(f"{n}: {v['records']} records" for n, v in m.items()))
