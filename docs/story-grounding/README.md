# Story grounding

Ask an author's own text a question and get an answer that says **how the story
knows it** — stated, worked out, unknown or contradicted — with the exact sentence
it rests on. Built from the handover *Companion Language Understanding and Story
Grounding*.

| Document | What it covers |
|---|---|
| [design.md](design.md) | The pipeline and model boundary, the reasons, the platform assumptions, and the six questions the handover asks |
| [schema.md](schema.md) | `story-grounding/1`: the JSONL record, token, entity, fact, evidence and answer fields |
| [annotation-guide.md](annotation-guide.md) | How to label sentences, with the edge cases decided |
| [proposal-mode.md](proposal-mode.md) | Opt-in suggestions labelled PROPOSED, and the rule that nothing is canon until the author says so |
| [character-knowledge.md](character-knowledge.md) | **Character Knowledge Continuity**: what a character knows or believes at a story point, how they learned it, possible knowledge leaks, linking without a second source of truth, the AI-status boundary |
| [knowledge-schema.md](knowledge-schema.md) | `knowledge-continuity/1`: the knowledge record, query kinds and expected answers |
| [evaluation.md](evaluation.md) | Held-out discipline, metrics per task, error review, and the first results with their limits |

## What exists

```
corpus/story_v1/        dev.jsonl (37) · heldout.jsonl (18) · MANIFEST.json · build.py
corpus/knowledge_v1/    dev.jsonl (21) · heldout.jsonl (17) · MANIFEST.json · build.py
lib/src/story/          tokenizer · tagger · extractor · index · question · retriever · proposals
                        knowledge · knowledge_question  (Character Knowledge Continuity)
tool/story_eval.dart    scores tagging, extraction, question parsing and answers separately
tool/knowledge_eval.dart scores knowledge events, knowledge answers and leak review items
test/story_grounding_test.dart
```

```dart
import 'package:authoros_language/authoros_language.dart';

final index = StoryIndex(EntityRegistry([
  const ProjectEntity(id: 'char_mara', type: EntityType.character, names: ['Mara'], pronouns: 'she'),
]));
index.ingest('scene_014_p03',
    'Mara quietly hid the silver key beneath the chapel floor before dawn.');

final a = index.ask('Where did the key end up?');
a.status;               // EvidenceStatus.derived
a.answer;               // 'beneath the chapel floor'
a.evidence.single.quote // the exact sentence, with start/end offsets into the source
```

The stages are separate and each can be run and inspected alone: `StoryTokenizer`,
`RuleTagger`, `FactExtractor`, `StoryIndex` (facts + sources), `QuestionParser`,
`StoryRetriever`. Proposal mode (`GroundedProposalGenerator`, `ProposalLedger`) never
feeds the index.

```sh
dart test                                              # unit tests, incl. the dev corpus
dart run tool/story_eval.dart dev                      # development set, with every miss listed
python3 -I corpus/story_v1/build.py --check            # corpus files match their sources
python3 -I corpus/knowledge_v1/build.py --check
dart run tool/knowledge_eval.dart dev
```

## What it is not (yet)

It is a rule-based first implementation on a corpus the rule author wrote. The
numbers in [evaluation.md](evaluation.md) are small-sample and must not be read as a
measure of how it will do on a real manuscript. The handover's milestone A exit check
(two annotators applying labels consistently) has **not** been done. See
[evaluation.md](evaluation.md#what-these-numbers-do-not-show).
