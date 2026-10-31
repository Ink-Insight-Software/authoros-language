# Design: pipeline, model boundary, and the handover's questions

> **Revised handover.** A later version of the handover adds Character Knowledge Continuity and
> replaces the six questions below with four. They are answered in
> [character-knowledge.md](character-knowledge.md) (AI status, linking to existing records,
> source-of-truth and story-version rules) and [evaluation.md](evaluation.md#answer-to-the-handovers-question-4-what-examples-and-tests-are-needed)
> (what examples and held-out tests are needed). The six answers below still stand for the
> language-understanding part.

## 1. What the platform allows (reviewed, not assumed)

| Fact | Evidence | Consequence |
|---|---|---|
| Companion is a standalone Flutter **web** app; the shared language layer is the pure-Dart package `authoros_language` | `companion/` pub workspace; this repo's `pubspec.yaml` | The layer cannot call Python/Java NLP libraries or native code in the browser. Anything shipped on the device is Dart, or a model run by a Dart-reachable runtime |
| Companion is deterministic and rule-based by default, data on the device, canon written only on explicit approval | AOS Companion docs and ADRs | Retrieval must be deterministic and must never write to canon; a generative component is opt-in and separate |
| The project owner builds and serves their own models rather than calling a third-party AI service | Decision recorded this session | No external model is in the default path; see §6 |

Assumptions the code makes where the repository does not say, and the evidence that
would settle each:

| Assumption | Evidence needed to confirm or change it |
|---|---|
| Manuscripts are English, third-person or first-person prose, a few thousand to a few hundred thousand words | Real manuscripts from the target authors; a language list from product |
| Passages arrive already split into scenes/paragraphs with stable ids | How Companion identifies text it is given (today: the caller supplies `sourceId`) |
| Most questions are short, single-fact questions ("where", "who", "when", "did") | A sample of what authors actually ask the Companion; the handover's examples are the only evidence so far |
| A query needs answering in well under a second on a laptop-class browser | Measured on the target devices. All I have: about 44 µs per word to ingest and ask over the 40 short dev passages (300 words) in the Dart VM on the build container, so roughly 4 s to ingest a 100,000-word manuscript. That is **not** a browser number, uses tiny passages, and retrieval scans facts linearly, so it is only a sanity check |
| Extraction can run at ingest time and be cached per passage | Product decision on when text is processed |

## 2. The pipeline and where the model boundary is

```
 text ──► tokenize ──► tag ──► extract facts ──► INDEX (facts + sources)
          offsets      POS     entities,         │
                       lemma   relations,        ▼
                               negation,   question ──► parse ──► retrieve ──► Answer
                               modality,                                       status + exact evidence
                               attribution
                                                           opt-in, separate:  proposals ──► ledger ──► author approves ──► canon path
```

Each stage has one input and one output type, so it can be replaced alone:

| Stage | Contract | Today | A learned replacement would be |
|---|---|---|---|
| Tokenize | text → sentences, tokens with exact offsets | `StoryTokenizer` (rules) | Not worth replacing |
| Tag | tokens → UPOS + lemma | `RuleTagger` (word lists + context rules) | A small UD-trained tagger behind `Tagger`; `pennToUpos` maps a Penn-tagset model to our labels |
| Extract | tagged sentences → `Fact`s | `FactExtractor` (chunking + explicit rules) | A relation-extraction model that fills the same `Fact` fields |
| Index | facts + sources, with source spans | `StoryIndex` | Unchanged (it is storage) |
| Parse question | text → intent, entities, verb | `QuestionParser` | A small intent classifier |
| Retrieve | question + facts → `Answer` | `StoryRetriever` (policy as code) | Stay deterministic: this is where STATED/DERIVED/UNKNOWN/CONFLICT is decided |
| Propose | UNKNOWN answer → `Proposal`s | `GroundedProposalGenerator` | A generative model behind `ProposalGenerator`, always behind `ProposalGuard` |

**Recommendation: hybrid, rule-first, Dart-native; learn the stages that have public
training data, keep the decision stage as code.**

- **Local operation.** Rules and word lists are plain Dart, run in the browser, need no
  download and no server. A trained model adds a download and a runtime; justify it per
  stage by a measured gain, not by default.
- **Privacy.** The default path sends nothing anywhere. Nothing in `lib/src/story/`
  imports `dart:io` or a network client. If a generative proposer is later wired in,
  only the passages named in the proposal request leave the device, and the UI must say
  so (see [proposal-mode.md](proposal-mode.md#what-leaves-the-device)).
- **Maintainability.** Every answer carries a trace (`Answer.trace`) and every fact
  points at its sentence, so a wrong answer can be traced to a stage and fixed by
  editing a list or a rule. A learned extractor can't be debugged that way. The cost: the
  rules cover what they were written for (see the limits in
  [evaluation.md](evaluation.md)).
- **Accuracy.** Tagging is the stage where a learned model clearly beats word lists on
  unseen vocabulary, and where public annotated English data exists (check each
  treebank's licence before use; not verified here). Fact extraction and retrieval policy
  are the stages where being *wrong silently* is worst, so they stay explicit until a
  model beats them on an independent held-out set.
- **Do not let a tagger retrieve facts.** Nothing in retrieval looks at POS tags; tags
  feed extraction, which produces facts, which are all retrieval sees.

## 3. The handover's six questions

**1. Which model boundary for the first prototype?** A hybrid: rules for every stage,
behind interfaces (`Tagger`, and the stage contracts above) that a trained model can
implement. The first model to try is the tagger; the last is the extractor; retrieval
policy never becomes a model. Each task is independently replaceable and scored
separately (`tool/story_eval.dart`).

**2. Which libraries fit the platforms, offline need, size and licence?** None are
needed for the prototype; it is pure Dart with no new dependencies. For a learned
stage, the realistic options for Flutter web are an ONNX or TFLite model run through a
web runtime, or a small Dart-native model. Server-side Python libraries (spaCy, Stanza,
NLTK and similar) fit a *server*, not the on-device requirement, and would need a
separate decision about what text leaves the device. *I have not verified current
versions, sizes or licences of any of these in this session; that check is a
prerequisite to choosing one.*

**3. Which tag inventory, and the mapping?** Universal Dependencies **UPOS** minus `X`
and `SYM` (the handover's 15 tags), as the `Upos` enum. A tagger with another inventory
is mapped at the boundary: `pennToUpos` does this for Penn Treebank tags (two tags are
context-dependent and documented as such: `TO` and `RP`). No other tag set appears
anywhere downstream. Auxiliary lemmas follow the corpus convention (surface form, not
`be`/`have`/`do`); the evaluation does not score them.

**4. Source-of-truth hierarchy.** Highest to lowest: **author-approved canon →
manuscript text → author notes → unapproved discoveries.** The rule that matters more
than the order: *a lower source never silently overrides a higher one, and a clash is
never resolved by the system*. Two sources that disagree give `CONFLICT` with both
references, each labelled with its kind (`EvidenceRef.kind`), and the author says which
is current. Within one kind, later text does not override earlier text (story time is
not reading order). The narrator's own statements outrank what a character said or
believed, which is used only when nothing else answers and is labelled with its
speaker. `SourceKind` and `EvidenceRef.kind` carry the hierarchy today; *ordering*
evidence by kind in the UI is a presentation task not built here.

**5. How proposal mode is entered, shown, accepted and stored.** See
[proposal-mode.md](proposal-mode.md). In short: explicit per-question opt-in, never a
default; shown in a separate area with a PROPOSED label and the exact story text that
inspired it; accept/edit/reject; stored only in a ledger outside the fact index; an
accepted proposal leaves the ledger only through an explicit approval, carrying its
grounding, to the existing save-a-copy canon path.

**6. Smallest representative corpus and evaluation set before choosing or training a
model?** For *choosing* between a rule stage and a model: a held-out set of a few
hundred sentences from at least three manuscripts the rules were not written against,
labelled independently by two people with agreement measured, covering each phenomenon
in the handover (§6 there) with at least ~20 instances each so a per-phenomenon score
means something. For *training* a tagger: public UD data is the starting point, with a
small in-domain set (fiction) added. What exists now (37 dev + 18 held-out records) is
the **smallest set that exercises every code path**, not a set big enough to choose a
model; see [evaluation.md](evaluation.md).

## 4. Privacy and project boundaries

- One `StoryIndex` per project; there is no cross-project state. Pronoun history and
  "unregistered names" live in the index's extractor.
- Facts, evidence and proposals are traceable to a `sourceId` and exact offsets.
- Changing a passage: `replace` / `remove` rebuild from scratch, in order, so pronouns and
  "later" stay consistent; there is no stale fact to correct by hand.
- No private manuscript text is used to train anything. The corpus here is
  author-written test text (by the rule author, not the user) and carries no manuscript
  content.

## 5. Why not only a tagger

A tagger answers "is *hid* a verb". It cannot say that Mara is the one who hid the key,
that "it" is the key, that "did not hide" is no event, or which passage answers a
question. Those need an entity registry (who exists), coreference (who "she" is, or
that it is unresolved), clause structure (subject, object, passive agent, prepositional
slots), polarity/modality/attribution, and a retrieval policy. They are separate stages
here and separately scored.

## 6. If a model is added later

A model can sit behind `Tagger`, behind a fact-extraction interface, or behind
`ProposalGenerator`. Rules for any of them: it runs on the project owner's own server
(per the decision this session) or on the device; the UI states what text it sees; its
output goes through the same `Fact` type, the same `ProposalGuard`, and the same
evaluation; and it replaces a rule stage only if it beats it on an independent held-out
set. Fine-tuning data follows `model/README.md`: public-domain, author-written, or
commercially licensed text only, nothing generated by a third-party AI service.
