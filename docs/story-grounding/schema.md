# Schema: `story-grounding/1`

One JSON object per JSONL line, in `corpus/story_v1/{dev,heldout}.jsonl`. The files are
**generated** from the example sources by `corpus/story_v1/build.py`, which computes
every character offset from the stored text and stops if a token is not where it
should be. `build.py --check` (run in CI) fails if the files are stale;
`MANIFEST.json` carries each file's record count and sha256.

## Versioning

- `schema_version` is `story-grounding/<major>`. Adding an optional field is not a
  version change. Renaming, removing or re-meaning a field is, and old files keep their
  version so results stay comparable.
- A dataset version is the pair (`schema_version`, `MANIFEST.json` hashes). Record it
  with every evaluation result (see [evaluation.md](evaluation.md)).
- The held-out file is **frozen**: it is committed before the rules it tests, and a
  change to it is a new held-out set, never an edit.

## Record

| Field | Type | Meaning |
|---|---|---|
| `schema_version` | string | `story-grounding/1` |
| `record_id` | string | Unique across both files |
| `split` | `dev` \| `heldout` | |
| `task` | `question_to_story_fact` \| `tagging` | Tagging records have no query |
| `project_id` | string | Facts never cross projects |
| `project_entities` | entity[] | What the author defined (below) |
| `sources` | source[] | The passages, in reading order |
| `query` | object \| null | The question as parsed (below) |
| `expected` | object \| null | The correct answer (below) |

### Entity (`project_entities[]`)

`{ "id": "char_mara", "type": "CHARACTER", "names": ["Mara"], "pronouns": "she" }`

`type` is one of `CHARACTER, PLACE, ITEM, GROUP, TIME, EVENT, OTHER`. `names` is the
list the linker matches (aliases are more names; multi-word names are not matched yet).
`pronouns` is what the author recorded (`she`, `he`, `they`) and is the only thing
pronoun resolution uses for characters; unset means "do not resolve to this character".
Items and places are not defined by the author; they are found in the text, with ids
built from their words: `item_key`, `place_chapel_floor`. The id prefix is the type.
`item_x` and `place_x` are treated as the same thing when matching (a "gate" is an
item in one sentence and a place in another).

### Source (`sources[]`)

```json
{ "source_id": "scene_014_p03",
  "text": "Mara quietly hid the silver key beneath the chapel floor before dawn.",
  "annotations": { "tokens": [ ... ], "facts": [ ... ] } }
```

`source_id` is the caller's identifier for a passage (project, document, chapter,
scene and paragraph can be encoded in it; the index treats it as opaque). `text` is
stored exactly; **all offsets are into this string**.

### Token (`annotations.tokens[]`)

| Field | Meaning |
|---|---|
| `text`, `start`, `end` | Surface form and its half-open character range in `text` |
| `pos` | UPOS: `NOUN PROPN VERB ADJ ADV PRON DET ADP AUX CCONJ SCONJ PART NUM INTJ PUNCT` |
| `lemma` | Lower-case lemma; PROPN keeps its capitals. Auxiliary and `n't` lemmas are the surface form in this corpus and are not scored |
| `role` | `SUBJECT ACTION OBJECT ATTRIBUTE LOCATION TIME MANNER CAUSE PURPOSE RECIPIENT SOURCE` (optional) |
| `entity_id`, `entity_type` | The entity a mention names, when it names one (optional) |

Contractions split as in UD: `didn't` → `did` + `n't`; `Duke's` → `Duke` + `'s`.
Quotation marks and other punctuation are `PUNCT` tokens. The compact notation used
in the example sources is `surface/POS[=lemma][@ROLE][#entity_id]`.

### Fact (`annotations.facts[]`)

```json
{ "fact_id": "d01_f1", "status": "STATED", "evidence_span": [0, 69],
  "subject": "char_mara", "relation": "hide", "object": "item_key",
  "location": "place_chapel_floor", "destination": null, "origin": null,
  "recipient": null, "time": "before dawn", "manner": "quietly", "attribute": null,
  "polarity": "affirmed", "modality": "certain", "attribution": null }
```

| Field | Values and rules |
|---|---|
| `subject`, `object` | Entity ids, or null. In a passive clause `subject` is the **agent** (null if none is stated) and `object` is what was acted on |
| `relation` | The verb's lemma, or `be` for a state or attribute |
| `location`, `destination`, `origin`, `recipient` | Entity ids (`in`/`under`/`at`…, `to`/`into`…, `from`, the receiver of a giving verb) |
| `time`, `manner`, `attribute` | The words as written, lower-case where a single word: `"before dawn"`, `"quietly"`, `"silver"` |
| `polarity` | `affirmed` \| `negated` (`not`, `n't`, `never`; also `could not`/`would not`) |
| `modality` | `certain` \| `possible` (`might`, `may`, `could`, `would`, `perhaps`, `maybe`) |
| `attribution` | `null` for the narrator, else `{ "speaker": id, "kind": "reported" \| "belief" }` |
| `unresolved_subject` | `true` when the subject was a pronoun with no single candidate (the subject is then null) |
| `status` | `STATED` on every extracted fact. `DERIVED`, `UNKNOWN`, `CONFLICT` are properties of **answers**; `PROPOSED` is a property of proposals; none is inferred from wording |
| `evidence_span` | `[start, end)` of the supporting sentence in the source text |

Colours and materials said of a noun phrase ("the silver key") are their own fact
(`relation: be`, `attribute: silver`).

### Query and expected answer

```json
"query": { "text": "Where did the key end up?", "intent": "retrieve_location",
           "entities": ["item_key"], "relation": null },
"expected": { "answer": "beneath the chapel floor", "answers": null,
              "status": "DERIVED", "evidence_ids": ["d01b_end_up"],
              "note": null, "offer_proposal": false, "attribution": null }
```

| `intent` | Asks |
|---|---|
| `retrieve_location` | Where something happened, or where a thing is |
| `retrieve_time` / `retrieve_manner` | When / how an event happened |
| `retrieve_attribute` | What colour (or material) a thing is |
| `retrieve_agent` | Who did it |
| `retrieve_object` | What was acted on |
| `yes_no` | Did X do Y |

`relation` is the verb the question uses, or null (`Where is the key?`). A question
that uses a synonym (`conceal`) is matched to facts using any word in the group
(`hide`, `conceal`, `stash`, `stow`); the gold may name the canonical verb.

`expected.answer` is in the **source's words**; `answers` lists the clashing values of
a `CONFLICT`. `evidence_ids` are `source_id`s. `note` is from a closed vocabulary:

| `note` | When |
|---|---|
| `possibility only` | The only matching fact is a "might" |
| `later moved` | A thing was placed and then something moved it |
| `unresolved reference` | The agent is a pronoun with more than one candidate |
| `agent not stated` | The fact exists but names no agent |
| `question not understood` | The parser could not read the question |

`offer_proposal` is true only when the story is **silent** (nothing relevant): it is
what lets the UI offer proposal mode. It is false when the story says something that
doesn't settle the question.

### Answer (what the pipeline returns; `Answer.toJson`)

`{ question, status, answer, answers, evidence[{source_id, start, end, quote, kind}],
note, offer_proposal, attribution }`. `quote` is `source.text.substring(start, end)`,
the exact sentence. `kind` is `canon | manuscript | note | discovery`.

### Proposal-mode records

Defined in [proposal-mode.md](proposal-mode.md); they are never `facts`.
