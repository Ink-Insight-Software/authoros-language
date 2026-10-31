"""Builds dev.jsonl and heldout.jsonl for knowledge_v1 from the example files.

    python3 -I corpus/knowledge_v1/build.py          # write the files
    python3 -I corpus/knowledge_v1/build.py --check  # fail if the files are out of date

Checks that every story_time_id is on the record's timeline, that sources are in story
order, and that every evidence id and gold-event source names a real source or author
record. See docs/story-grounding/knowledge-schema.md for the record format.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))

from common import ENTITIES  # noqa: E402
from heldout_examples import HELDOUT  # noqa: E402

try:
    from dev_examples import DEV  # noqa: E402
except ModuleNotFoundError:
    DEV = []

SCHEMA = "knowledge-continuity/1"
STATES = {"KNOWS", "BELIEVES", "SUSPECTS", "MISREMEMBERS", "AUTHOR_CONFIRMED_UNAWARE", "UNAWARE_IN_TEXT"}
ROUTES = {"WITNESSED", "TOLD", "OVERHEARD", "READ", "EXPERIENCED", "INFERRED", "AUTHOR_ENTERED"}
STATUSES = {"STATED", "DERIVED", "UNKNOWN", "CONFLICT"}
KINDS = {"knows", "who_knows", "when_learned", "leak_check"}


def record(ex: dict, split: str) -> dict:
    tl = [t["id"] for t in ex["timeline"]]
    if len(set(tl)) != len(tl):
        raise ValueError(f"{ex['id']}: duplicate timeline ids")
    last = -1
    for s in ex["sources"]:
        if s["story_time_id"] not in tl:
            raise ValueError(f"{ex['id']}: {s['source_id']} is at {s['story_time_id']!r}, not on the timeline")
        pos = tl.index(s["story_time_id"])
        if pos < last:
            raise ValueError(f"{ex['id']}: sources must be listed in story order")
        last = pos
    for a in ex["author_records"]:
        if a["story_time_id"] not in tl:
            raise ValueError(f"{ex['id']}: author record {a['record_id']} is off the timeline")
        if a["knowledge_state"] not in STATES:
            raise ValueError(f"{ex['id']}: unknown state {a['knowledge_state']!r}")
    ids = {s["source_id"] for s in ex["sources"]} | {a["record_id"] for a in ex["author_records"]}
    q, e = ex["query"], ex["expected"]
    if q["kind"] not in KINDS:
        raise ValueError(f"{ex['id']}: unknown query kind {q['kind']!r}")
    at = q.get("story_time_id")
    # A point is an entry on the timeline, or a group of entries ("chapter_02" is the end of
    # chapter_02_scene_01, chapter_02_scene_03, ...).
    if at and not any(t == at or t.startswith(at + "_") for t in tl):
        raise ValueError(f"{ex['id']}: query time {at!r} is not on the timeline")
    for i in e.get("evidence_ids", []):
        if i not in ids:
            raise ValueError(f"{ex['id']}: evidence {i!r} is not one of {sorted(ids)}")
    if e.get("status") and e["status"] not in STATUSES:
        raise ValueError(f"{ex['id']}: unknown status {e['status']!r}")
    if e.get("knowledge_state") and e["knowledge_state"] not in STATES:
        raise ValueError(f"{ex['id']}: unknown state {e['knowledge_state']!r}")
    if e.get("acquisition_route") and e["acquisition_route"] not in ROUTES:
        raise ValueError(f"{ex['id']}: unknown route {e['acquisition_route']!r}")
    for g in ex["gold_events"]:
        if g["source_id"] not in ids:
            raise ValueError(f"{ex['id']}: gold event source {g['source_id']!r} unknown")
        if g["knowledge_state"] not in STATES or (g["acquisition_route"] and g["acquisition_route"] not in ROUTES):
            raise ValueError(f"{ex['id']}: bad gold event {g}")
    return {
        "schema_version": SCHEMA, "record_id": ex["id"], "split": split, "project_id": "demo_project",
        "project_entities": ENTITIES, "timeline": ex["timeline"], "sources": ex["sources"],
        "author_records": ex["author_records"], "query": q, "expected": e, "gold_events": ex["gold_events"],
    }


def build() -> dict[str, str]:
    ids = [e["id"] for e in DEV] + [e["id"] for e in HELDOUT]
    dupes = {i for i in ids if ids.count(i) > 1}
    if dupes:
        raise ValueError(f"duplicate record ids: {sorted(dupes)}")
    out = {}
    for name, examples in (("dev", DEV), ("heldout", HELDOUT)):
        if not examples:
            continue
        out[f"{name}.jsonl"] = "".join(
            json.dumps(record(e, name), ensure_ascii=False, sort_keys=True) + "\n" for e in examples
        )
    manifest = {
        "schema_version": SCHEMA,
        "files": {n: {"records": t.count("\n"), "sha256": hashlib.sha256(t.encode()).hexdigest()}
                  for n, t in out.items()},
    }
    out["MANIFEST.json"] = json.dumps(manifest, indent=2) + "\n"
    return out


if __name__ == "__main__":
    files = build()
    if "--check" in sys.argv:
        stale = [n for n, t in files.items() if not (HERE / n).exists() or (HERE / n).read_text() != t]
        if stale:
            sys.exit(f"out of date: {', '.join(stale)}; run build.py")
        print("knowledge corpus files are up to date")
    else:
        for n, t in files.items():
            (HERE / n).write_text(t)
        m = json.loads(files["MANIFEST.json"])["files"]
        print(", ".join(f"{n}: {v['records']} records" for n, v in m.items()))
