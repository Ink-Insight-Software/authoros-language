# Changelog

## Unreleased

- **Character Knowledge Continuity** (`lib/src/story/knowledge*.dart`,
  `corpus/knowledge_v1/`, `docs/story-grounding/character-knowledge.md`). What a character
  knows, believes, suspects or has wrong at a story point, how they learned it (told,
  witnessed, overheard, read, inferred, author-entered), with the exact passage. Being told
  is believing unless the narrator confirms it; no record is UNKNOWN, never "does not know";
  a belief stays separate from what the story says; a possible knowledge leak is a review
  item with both passages. Story time is an explicit timeline. A derived index: rebuilt from
  passages and author records, never a second source of truth. Rule-based, deterministic and
  versioned (`kStoryPipelineVersion`). Small-sample, author-written evaluation; see
  `docs/story-grounding/evaluation.md`.

- **Story grounding** (`lib/src/story/`, `docs/story-grounding/`,
  `corpus/story_v1/`). Ask an author's own text a question and get an answer that
  says whether it is STATED, DERIVED, UNKNOWN or CONFLICT, with the exact sentence it
  rests on. Rule-based and Dart-only, in separate stages (tokenize, tag, extract
  facts, index, parse question, retrieve) that can each be replaced. Negation,
  modality, passive voice, reported speech and pronouns are handled; an ambiguous
  pronoun stays unresolved and a clash is reported, not resolved. Opt-in proposal
  mode keeps PROPOSED suggestions in a ledger outside the fact index until the author
  approves. Ships a versioned corpus (37 dev, 18 held-out records), its builder, an
  evaluation tool and the first results with their limits. Not a statistical model;
  small-sample, author-written evaluation: see `docs/story-grounding/evaluation.md`.

## 0.2.0

- **The Dart client for your own model server.** `OwnModelClient` (calls
  `model/serve.py`; https required except on this machine), `ChatGuard` (one short
  plain line, no names, digits, markup or quotation marks, not just an echo),
  `ModelBackedChat` (greetings and light conversation, with the rule-based lines as
  the floor on any failure) and `tool/chat.dart`. Additive. Adds a dependency on
  `http`.
- `model/serve.py` now reads a request's body before answering, so a wrong token is
  reported as refused rather than as a dropped connection.

## 0.1.0

- **Moved in from AOS Companion's engine, unchanged.** The rule-based language
  layer (delivery, listening, reading, answering, the tone banks and the voice
  sample) and the vocabulary it speaks in (voice profile, relationship stage and
  behaviour, topic access, the author response analysis). Tests that need only
  these moved with them; tests that also need Companion's project, journal or
  conversation stay there.
