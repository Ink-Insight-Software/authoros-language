"""Pull approved training lines from Supabase into the authoring format.

    export SUPABASE_URL=https://<ref>.supabase.co
    export SUPABASE_SERVICE_KEY=...            # the service role key: keep it off disk and out of git
    python model/supabase_export.py            # writes model/authoring/supabase-*.md
    python model/authoring.py check model/authoring/supabase-*.md
    python model/authoring.py build model/authoring/*.md

Only rows with status 'approved' are exported. The lines go through authoring.py's
checker like any others, which also holds them to the no-names rule the database
cannot express. Standard library only.

Approving a line is a deliberate step by you, with the service role (the dashboard's
table editor, or SQL): writers cannot approve their own lines.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path

OUT = Path(__file__).parent / "authoring"
PAGE = 1000


def fetch(url: str, key: str) -> list[dict]:
    rows: list[dict] = []
    while True:
        q = urllib.parse.urlencode({
            "select": "voice,length,moment,author_line,reply,written_by,rights,ai_assisted",
            "status": "eq.approved",
            "order": "written_by.asc,voice.asc,length.asc,moment.asc,created_at.asc",
            "limit": PAGE,
            "offset": len(rows),
        })
        req = urllib.request.Request(
            f"{url}/rest/v1/training_lines?{q}",
            headers={"apikey": key, "authorization": f"Bearer {key}"},
        )
        with urllib.request.urlopen(req, timeout=30) as r:
            page = json.loads(r.read())
        rows.extend(page)
        if len(page) < PAGE:
            return rows


def render(written_by: str, rights: str, rows: list[dict]) -> str:
    out = [
        "# Exported from Supabase (approved lines). Edit them there, not here.",
        f"written-by: {written_by}",
        f"rights: {rights}",
        "ai-assisted: no",
        "",
    ]
    by_voice: dict[tuple, dict[str, list[dict]]] = defaultdict(lambda: defaultdict(list))
    for r in rows:
        by_voice[(r["voice"], r["length"])][r["moment"]].append(r)
    for (voice, length), moments in by_voice.items():
        out += [f"voice: {voice}", f"length: {length}", ""]
        for moment in ("opening", "returning", "chat", "farewell"):
            if moment not in moments:
                continue
            out.append(f"[{moment}]")
            for r in moments[moment]:
                if r["author_line"]:
                    out.append(f"> {r['author_line']}")
                out.append(r["reply"])
                out.append("")
    return "\n".join(out)


def main() -> int:
    url, key = os.environ.get("SUPABASE_URL", ""), os.environ.get("SUPABASE_SERVICE_KEY", "")
    if not url or not key:
        print("set SUPABASE_URL and SUPABASE_SERVICE_KEY", file=sys.stderr)
        return 2
    rows = fetch(url.rstrip("/"), key)
    if any(r["ai_assisted"] for r in rows):  # the database forbids it; belt and braces
        print("refusing: a row is marked AI-assisted", file=sys.stderr)
        return 1
    groups: dict[tuple, list[dict]] = defaultdict(list)
    for r in rows:
        groups[(r["written_by"], r["rights"])].append(r)
    for old in OUT.glob("supabase-*.md"):
        old.unlink()
    OUT.mkdir(exist_ok=True)
    for i, ((who, rights), rs) in enumerate(sorted(groups.items()), 1):
        (OUT / f"supabase-{i:02d}.md").write_text(render(who, rights, rs), encoding="utf-8")
    print(f"{len(rows)} approved lines from {len(groups)} writer/rights group(s) -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
