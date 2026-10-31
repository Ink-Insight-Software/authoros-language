# Character Knowledge Continuity

What a character knows, believes, suspects or has wrong **at a point in the story**, how
the information reached them, and the exact words that say so. From the revised handover
*Language and character knowledge continuity*. Built on the story-grounding pipeline; the
schema is in [knowledge-schema.md](knowledge-schema.md), the results in
[evaluation.md](evaluation.md#character-knowledge-continuity).

```dart
final index = StoryIndex(registry, timeline: timeline); // the app's story order
index.ingest('ch02_s04_p12', 'Mara told Iven that she hid the key.',
    storyTimeId: 'chapter_02_scene_04');

final a = index.askKnowledge('Does Iven know Mara hid the key by Chapter 3?');
a.status;     // EvidenceStatus.stated
a.state;      // KnowledgeState.knows   (BELIEVES unless the narrator confirms it)
a.route;      // AcquisitionRoute.told
a.evidence;   // the exact sentence, with offsets, in ch02_s04_p12
a.matchesCanon; // true: the story itself says Mara hid the key

index.askKnowledge('Who knows Mara hid the key by Chapter 2?').who;
index.askKnowledge('When did Iven learn that Mara hid the key?').storyTimeId;
index.knowledgeLeaks(); // review items, never errors
```

## The rules

| Rule | Why |
|---|---|
| **Being told is not knowing.** A character told something the narrator confirms **KNOWS** it; told something the narrator does not confirm (or contradicts) **BELIEVES** it | A character can be lied to. The handover's example (Iven hears Mara admit it, and the story states it) is KNOWS/TOLD; a rumour is a belief |
| **No record is not ignorance.** With no acquisition on file the answer is `UNKNOWN`, note *no recorded acquisition found* | "Do not turn missing evidence into proof of ignorance" |
| **Learning it later is not ignorance before.** Asked "by Chapter 3" when the only acquisition is in Chapter 4: `UNKNOWN`, note *first recorded acquisition is later*, citing that passage | Same rule; the later passage is shown, the earlier state is not guessed |
| **A belief stays separate from canon.** Every answer carries `matchesCanon`: true, false (the story says otherwise) or null | A false belief is a belief, not a contradiction |
| **A negated or hedged telling records nothing.** "did not tell…", "might tell…" assert no clause | Nothing was said |
| **A negated or hedged *knowing* still presupposes the clause.** "did not know that Mara hid it" says Mara hid it, and that Iven was unaware | Factive verbs presuppose their complement |
| **Two passages at one moment that disagree about awareness are a `CONFLICT`**, as is knowing and then being recorded as unaware | Surfaced, never settled by the system |
| **Everything is cited.** Each event points at a sentence (or an author record) | Traceable, inspectable |

## States and routes

`KnowledgeState`: `KNOWS`, `BELIEVES`, `SUSPECTS`, `MISREMEMBERS`, `AUTHOR_CONFIRMED_UNAWARE`
(the handover's five) and **`UNAWARE_IN_TEXT`** (*added*: the text itself says the character
did not know; kept apart from the author-entered state. Confirm it or fold it into
`AUTHOR_CONFIRMED_UNAWARE`).

| What the sentence says | State | Route |
|---|---|---|
| X **told** Y that P | Y: KNOWS if the narrator confirms P, else BELIEVES | TOLD |
| X **saw / watched / noticed** P, or "saw her hide it" | X: KNOWS | WITNESSED |
| X **heard / overheard** that P | X: KNOWS or BELIEVES (as above) | OVERHEARD |
| X **read** that P | X: KNOWS or BELIEVES (as above) | READ |
| X **realized / understood / deduced** that P | X: KNOWS | INFERRED |
| X **suspected** that P | X: SUSPECTS | INFERRED |
| X **believed / thought / assumed** that P | X: BELIEVES | none stated |
| X **knew / learned / discovered** that P | X: KNOWS | none stated |
| X **misremembered** that P | X: MISREMEMBERS | none stated |
| X **did not know** that P | X: UNAWARE_IN_TEXT | none stated |
| X did P (a deliberate action) | X: KNOWS | EXPERIENCED |
| the author recorded it | as recorded | AUTHOR_ENTERED |

A route the text does not state is `null`, not guessed (the handover's route list has no
"unspecified"; adding one is a choice to confirm).

## Story time

`StoryTimeline` is an ordered list of ids with labels. Chapter and scene are ids that share a
prefix (`chapter_02`, `chapter_02_scene_04`), so *by Chapter 2* is the end of everything under
`chapter_02`, and *by Chapter 2, Scene 1* is earlier than Scene 3. A point the timeline does
not have answers `UNKNOWN`, note *story point not found*, never a guess. Where an application
already keeps story order, it passes it in and the timeline holds no authority; with none,
reading order is story order. Flashbacks need the application's own story time, not reading
order.

## Possible knowledge leaks

`knowledgeLeaks()` returns review items. **One pattern is implemented**, the one the handover
describes: the narrator states a hiding or placement; a *later* passage has a *different*
character acting on the same object or place; and that character has no recorded acquisition
of the fact before the action. Each item carries the action passage, the establishing passage,
the character's first (later) acquisition if there is one, and the timeline order of all three.
Not flagged: the hider, anyone who was told or saw it first, or an action that comes before the
hiding. An item is "possible": a flashback, an unreliable narrator or an intended reveal can
explain it, and nothing is rewritten or called an error. Other leaks (a character using
information from a letter they have not read, for example) are not detected.

## What it does not do

- It reads **sentences that report taking something in**. It does not infer that Iven knows
  something because he was present in a scene, or because he behaves as if he did.
- "Told" needs a named recipient; "Mara said that…" with no listener creates no event.
- Perception of the form *saw that…* and *saw X do Y* is handled; *overheard Mara say that…*
  (a perception verb followed by a saying verb) is not.
- One proposition per clause: the first fact of the embedded clause. "She hid the key and the
  map" yields events for the key only.
- Questions: three forms ("Does X know …?", "Who knows …?", "When did X learn …?"), with
  "by/in/at Chapter N" or "Scene N". "Could Lucia know this in Chapter 3?" and
  "Which characters believe the false accusation?" are not parsed; the second is
  answerable through `knowledge.events` but has no question form.
- A proposition is matched on its verb (with synonyms), subject and object, and for a state on
  the place or attribute. Time and manner are ignored.

## Linking to existing records without a second source of truth

*(The handover's question 2.)* What Companion has today, from the repository:

| Existing | What it is | Relation to knowledge continuity |
|---|---|---|
| Characters (`ProjectEntity`, `CompanionProject`) | The author's characters, with pronouns | `character_id` is *their* id; nothing is copied |
| Discoveries and canon (`journal/`) | What the author said and confirmed, approved explicitly | The path by which an author-approved fact becomes a passage with `SourceKind.canon` |
| `CharacterMemory` (`memory/`) | What the **character remembers when talking**, built only from approved discoveries | Different thing: conversational memory, not story-time knowledge. They are not merged |
| `StoryGraphLinks` | Suggested links from a discovery to a Story Graph character/location/scene id supplied by the host | The pattern for linking by id and by approval |
| "Timelines" (`alternate/`) | **Alternate versions** of a story | Not story chronology |
| Timeline, Story Graph and Knowledge Graph records | **Not in this repository** (they live in the shared AuthorOS apps) | The host passes ids in; this code holds none |

So the design is: **a knowledge event is a derived index entry made of ids and evidence**
(`character_id`, `proposition_id` as a fact id or the host's canonical record id,
`story_time_id`, `evidence_refs`), rebuilt from the passages and author records on every
change. It is never edited directly and never written back by itself. Deleting or changing a
passage changes or removes its events; there is no stale copy to reconcile. The only
author-originated knowledge is an `AuthorKnowledgeRecord`, entered by an explicit author
action (and, in Companion, saved through the existing approve-then-save-a-copy canon path).
If the host already has a Knowledge Graph, events are *suggestions to link* (the
`StoryGraphLinks` pattern: nothing is linked until the author approves that link), and the
host's record is the authority.

## Source-of-truth and story-version rules

*(Question 3.)* The hierarchy from [design.md](design.md#3-the-handovers-six-questions) applies
(author-approved canon, manuscript, notes, unapproved discoveries; no silent override; a
clash is a `CONFLICT`). For knowledge: an author record and a passage that disagree about
awareness at the same moment, or knowing followed by unawareness, are reported as conflicts.
**One `StoryIndex` is one draft** (`draftId`); events and answers are about that draft and
story point only, and drafts are never mixed. Comparing two drafts means building two indexes
and diffing their answers; that comparison is not built.

## Positioning boundary: is this AI?

*(Question 1.)* The handover notes that a trained POS or entity model is AI-based language
processing even when local and repeatable, and asks to confirm the product's promise before
choosing. What I can say, and what I cannot:

- **What is built contains no trained model and no generation.** It is word lists and
  explicit rules in Dart, and it is repeatable: the same text, entities, timeline and
  `kStoryPipelineVersion` give the same facts, events and answers (a test asserts this).
  That fits the handover's "Deterministic Continuity" wording **provided the inputs are
  versioned** (the pipeline version, the project's entity list and timeline, the text), and
  provided the product does not call it "AI-free" if it ever adopts a trained tagger.
- **I cannot decide the product promise.** Whether "AI-free" excludes a local, non-generative
  trained model is a product decision. Recommendation: ship the rule-based tier as
  **Deterministic Continuity** (no trained model, no generation); treat a trained tagger as a
  separate, disclosed upgrade behind `Tagger`; keep anything that writes story text in
  [proposal mode](proposal-mode.md), labelled and opt-in.
- **Evidence needed:** the product's exact wording of the promise; the platform and licence
  constraints for any model (not verified here).
