"""Shared helpers for writing knowledge_v1 examples (Character Knowledge Continuity).

Written by Claude as test cases for a rule-based pipeline; an evaluation set, not
training data for a model. Every sentence is original text written for this corpus.
"""

ENTITIES = [
    {"id": "char_mara", "type": "CHARACTER", "names": ["Mara"], "pronouns": "she"},
    {"id": "char_iven", "type": "CHARACTER", "names": ["Iven"], "pronouns": "he"},
    {"id": "char_edda", "type": "CHARACTER", "names": ["Edda"], "pronouns": "she"},
    {"id": "char_rowan", "type": "CHARACTER", "names": ["Rowan"], "pronouns": "he"},
    {"id": "char_tom", "type": "CHARACTER", "names": ["Tom"], "pronouns": "he"},
    {"id": "char_lucia", "type": "CHARACTER", "names": ["Lucia"], "pronouns": "she"},
]


def TL(*ids):
    """A story timeline: ids in story order. Label is the id spelt for people."""
    out = []
    for i in ids:
        parts = i.split("_")
        label = ", ".join(
            f"{parts[k].capitalize()} {int(parts[k + 1])}" for k in range(0, len(parts) - 1, 2)
        )
        out.append({"id": i, "label": label})
    return out


def src(source_id, story_time_id, text):
    return {"source_id": source_id, "story_time_id": story_time_id, "text": text}


def prop(subject, relation, obj=None, **slots):
    """A proposition: the story fact a character may know."""
    p = {"subject": subject, "relation": relation, "object": obj}
    p.update(slots)
    return p


def ev(character_id, proposition, state, route, source_id):
    """A gold knowledge event."""
    return {"character_id": character_id, "proposition": proposition,
            "knowledge_state": state, "acquisition_route": route, "source_id": source_id}


def knows(text, character_id, proposition, at):
    return {"kind": "knows", "text": text, "character_id": character_id,
            "proposition": proposition, "story_time_id": at}


def who(text, proposition, at):
    return {"kind": "who_knows", "text": text, "proposition": proposition, "story_time_id": at}


def when(text, character_id, proposition):
    return {"kind": "when_learned", "text": text, "character_id": character_id,
            "proposition": proposition, "story_time_id": None}


def leaks_query():
    return {"kind": "leak_check", "text": "Check for possible knowledge leaks.",
            "story_time_id": None}


def exp_knows(state, status, route, evidence, canon=None, note=None):
    return {"knowledge_state": state, "status": status, "acquisition_route": route,
            "evidence_ids": evidence, "matches_canon": canon, "note": note}


def exp_who(names, status, evidence):
    return {"who": names, "status": status, "evidence_ids": evidence}


def exp_when(time_id, status, evidence):
    return {"story_time_id": time_id, "status": status, "evidence_ids": evidence}


def exp_leaks(items):
    """items: (character_id, action_source_id, proposition_source_id)"""
    return {"leaks": [{"character_id": c, "action_source_id": a, "proposition_source_id": p}
                      for c, a, p in items]}


def K(rid, timeline, sources, query, expected, events=None, author=None):
    return {"id": rid, "timeline": timeline, "sources": sources, "author_records": author or [],
            "query": query, "expected": expected, "gold_events": events or []}
