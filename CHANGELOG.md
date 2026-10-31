# Changelog

## Unreleased

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

## 0.1.0

- **Moved in from AOS Companion's engine, unchanged.** The rule-based language
  layer (delivery, listening, reading, answering, the tone banks and the voice
  sample) and the vocabulary it speaks in (voice profile, relationship stage and
  behaviour, topic access, the author response analysis). Tests that need only
  these moved with them; tests that also need Companion's project, journal or
  conversation stay there.
