"""Shared helpers for writing story_v1 examples. See heldout_examples.py."""

# The project's known characters. Items, places and everything else are found in
# the text, so they are not listed. `pronouns` is what the author recorded for them.
ENTITIES = [
    {"id": "char_mara", "type": "CHARACTER", "names": ["Mara"], "pronouns": "she"},
    {"id": "char_iven", "type": "CHARACTER", "names": ["Iven"], "pronouns": "he"},
    {"id": "char_edda", "type": "CHARACTER", "names": ["Edda"], "pronouns": "she"},
    {"id": "char_rowan", "type": "CHARACTER", "names": ["Rowan"], "pronouns": "he"},
    {"id": "char_tom", "type": "CHARACTER", "names": ["Tom"], "pronouns": "he"},
]


def S(source_id, text, tokens, facts):
    """One source passage: its text, its gold tokens (compact notation) and its facts."""
    return {"source_id": source_id, "text": text, "tokens": tokens, "facts": facts}


def fact(subject, relation, obj, *, location=None, destination=None, origin=None,
         recipient=None, time=None, manner=None, attribute=None, polarity="affirmed",
         modality="certain", attribution=None, unresolved_subject=False):
    """A gold fact. Places are entity ids; time, manner and attribute are text."""
    f = {
        "subject": subject, "relation": relation, "object": obj,
        "location": location, "destination": destination, "origin": origin,
        "recipient": recipient, "time": time, "manner": manner, "attribute": attribute,
        "polarity": polarity, "modality": modality, "attribution": attribution,
        "status": "STATED",
    }
    if unresolved_subject:
        f["unresolved_subject"] = True
    return f


def Q(text, intent, entities, relation, answer, status, evidence_ids, *,
      note=None, answers=None, offer_proposal=False, attribution=None):
    """A question and what a correct answer to it is."""
    return {
        "query": {"text": text, "intent": intent, "entities": entities, "relation": relation},
        "expected": {
            "answer": answer, "answers": answers, "status": status,
            "evidence_ids": evidence_ids, "note": note,
            "offer_proposal": offer_proposal, "attribution": attribution,
        },
    }
