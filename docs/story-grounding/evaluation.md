# Evaluation plan and first results

## Principles

1. **Score each task separately.** A system that tags well and retrieves the wrong fact
   must show as such. `tool/story_eval.dart` reports tagging, fact extraction, question
   parsing and answers apart, and answers twice: from the **gold** parse of the question
   ("oracle", which isolates extraction and retrieval) and from the **parser** ("end to
   end").
2. **A held-out set that is not used for fitting or tuning.** `heldout.jsonl` was
   committed (`d884d1d`) *before* any rule existed. Rules were written and debugged
   against `dev.jsonl` and against ad-hoc sentences of the rule author's own. The
   held-out set was run once on the finished pipeline (`ada8a4e`); the output is kept
   in `results/heldout-first-run.json`. Any change after that point is labelled
   *post-hoc* below and the held-out numbers are not re-reported.
3. **Report the first run, with its limits.** See
   [what these numbers do not show](#what-these-numbers-do-not-show).
4. **Review errors, then add corrected examples to the dev set** (never the frozen
   held-out set), and bump the dataset version when a file changes.
5. **Record what produced a number**: dataset version (`MANIFEST.json` hashes), schema
   version, and the git commit of the pipeline, with every report.

## Metrics by task

| Task | Metric (as implemented) | Failure cases the data targets |
|---|---|---|
| POS and lemma | Accuracy; per-label precision, recall, F1 and support; open-class lemma accuracy (auxiliary lemmas are not scored) | Names that look like nouns (`Rowan rowed`), participle-adjectives, auxiliaries, contractions, infinitive `to` |
| Entity and reference linking | Scored through facts: a wrong entity id makes the fact not match. Unresolved pronouns are expected to stay unresolved (`unresolved_subject`). *Span F1 and a separate link-rate are not computed* | Aliases, pronouns with two candidates, items that are also places |
| Fact and relation extraction | Exact fact match (every slot, polarity, modality, attribution); precision, recall, F1 over facts | Negation, passive, modality, attribution, time/location attachment |
| Question parsing | Intent, relation and entity-set accuracy against the gold parse | Wh-forms, `end up`, synonyms |
| Retrieval and answers | Answer correct = status **and** answer text **and** evidence ids all match (for `CONFLICT`, the set of clashing answers); evidence precision/recall; note, offer-proposal flag and attribution scored separately | Paraphrase, unsupported questions, conflicts, moved objects |
| Status classification | Accuracy plus the gold→predicted confusion matrix | Inference shown as canon; contradiction suppressed |

Not built: multi-hop questions, time-scoped questions, ranked retrieval (answers are
deterministic lookups, not a ranked list), and a PROPOSED-status classifier (proposals
are made by a separate stage and are `PROPOSED` by construction).

## Error-review steps

1. Run `dart run tool/story_eval.dart dev`. Every miss is printed with the gold and the
   output.
2. Classify each miss: **tagger**, **extractor** (which slot), **question parser**,
   **retrieval policy**, **corpus label**, or **convention** (both defensible; decide in
   the [annotation guide](annotation-guide.md)).
3. Fix the stage that caused it, add the case to the dev set or a unit test, re-run.
4. If a miss is a corpus label, fix the label and say so in the commit.
5. Review the held-out misses **only to report them**; do not fit to them.
6. For a real manuscript: show the author the misses as "did we get this right?" and
   add their corrections as new dev examples with their consent.

## First results

Dataset `story-grounding/1`: `dev.jsonl` 37 records, `heldout.jsonl` 18 records
(`MANIFEST.json`).

| | Dev (rules written against it) | **Held-out, first run** (`ada8a4e`) |
|---|---|---|
| Records / question records | 37 / 29 | 18 / 16 |
| POS accuracy | 351/351 | 174/174 |
| Open-class lemma | 177/177 | 86/86 |
| Fact extraction P / R / F1 | 100 / 100 / 100 | **85.7 / 85.7 / 85.7** (18 of 21) |
| Question parsing: intent / relation / entities | 29/29 each | 16/16 · **15/16** · **15/16** |
| Answers, oracle query | 29/29 | **15/16** |
| Answers, end to end | 29/29 | 16/16 |
| Evidence precision / recall | 100 / 100 | 100 / 100 |
| Note / offer flag / attribution | 2/2 · 29/29 · 29/29 | **1/2** · 16/16 · 16/16 |

Held-out by status (all end to end): STATED 11/11, DERIVED 1/1, UNKNOWN 3/3, CONFLICT
1/1. By intent: location 4/4, agent 5/5, yes/no 3/3, attribute 1/1, time 1/1, manner
1/1, object 1/1. Held-out tag coverage: no `INTJ` or `NUM` tokens at all, so those
labels are untested there (the dev set has both).

### The held-out misses, reviewed

| Miss | Class | Cause | Disposition |
|---|---|---|---|
| Three facts about `the gate` (`item_gate` in the gold, `place_gate` from the pipeline); oracle answer to "What colour is the gate?" is UNKNOWN instead of CONFLICT | extractor (**a real defect**) | `gate` is on the place-noun list, so the id depends on a word list. The pipeline is self-consistent (source and question both say `place_gate`, so end to end passes) but cannot match a question whose entity id says `item_` | **Post-hoc fix**: `item_x` and `place_x` match as the same thing (`sameEntity`), with a unit test on a different sentence. Not re-run on held-out |
| Relation `conceal` vs gold `hide` | convention | The gold names the canonical verb; the pipeline keeps the question's verb and matches by synonym group. The *answer* was right | Documented in [schema.md](schema.md); parsing score is conservative |
| Note `ambiguous pronoun` vs gold `unresolved reference` | convention | Wording only; status, answer and evidence were right | **Post-hoc**: adopted the gold vocabulary |

Other changes since the run, none motivated by a held-out result: `brass` and `gold`
count as colour words (the handover's own example is a brass/silver conflict, found by
a unit test); `Answer` evidence now carries the source kind; the eval tool gained
per-label and evidence metrics (the first run was re-executed on its original code with
the new tool and reproduced every headline number).

## What these numbers do not show

- **Small and one author.** 55 records, 16 question records in the held-out set. One
  mistake changes a score by 6 points. The held-out set has 18 sentences' worth of
  coverage; it exercises each phenomenon once or twice, which tests that the code path
  exists, not how often it works.
- **Written by the author of the rules.** The same person wrote the held-out sentences,
  the dev sentences and the rules. The held-out set was frozen first, which prevents
  fitting to it, but it does not prevent the author's blind spots from being shared by
  all three. Wording that this author would not think of is not in it.
- **Clean, short sentences.** Real fiction has long, embedded and elliptical sentences,
  dialect and fragments. 100% POS on short clean sentences says little about a novel.
- **Rules tuned to known vocabulary.** The tagger and extractor use word lists; the
  held-out words were probably in or near them (I did not measure the overlap). Unseen vocabulary will do worse, and an
  unknown word at the start of a sentence is guessed to be a name.
- **Not annotator-checked.** The milestone A exit check (two independent labellers,
  measured agreement) is not done. Some labels are conventions this author chose.
- **No real manuscript, no browser, no author.** Nothing here was run on a real
  manuscript, on a browser, or with an author reading the answers.

## What would make the evaluation credible

1. A second held-out set (v2) of a few hundred sentences, written or collected by
   *other people* from text the rules have not seen, with at least ~20 instances of each
   handover phenomenon; labelled independently by two annotators, agreement reported,
   disagreements resolved in the guide.
2. Consented real-manuscript passages, with the author marking each answer right/wrong,
   reported as a separate row.
3. Per-phenomenon scores (negation, modality, pronoun, attribution, conflict, unknown)
   with counts, so a 100% on two examples isn't read as 100%.
4. Run the pipeline in the actual browser build and report latency on a 100,000-word
   manuscript.
5. Re-run this table on every change to the rules, with the dataset hashes.

## Character Knowledge Continuity

Same discipline as above: `corpus/knowledge_v1/heldout.jsonl` (17 records) was committed
(`cdd2c36`) before any knowledge rule existed; the rules were developed on `dev.jsonl` (21
records) and on sentences of my own; the held-out set was run **once** on the finished code
(`e90757e`), report in `results/knowledge-heldout-first-run.json`. Run it with
`dart run tool/knowledge_eval.dart heldout`.

| | Dev (rules written against it) | **Held-out, first run** (`e90757e`) |
|---|---|---|
| Records / question records | 21 / 18 | 17 / 17 |
| Event extraction P / R / F1 (against gold events) | 100 / 100 / 100 (10 of 10) | **93.8 / 93.8 / 93.8** (15 of 16) |
| Answers, from the gold-structured query | 18/18 | 15/15 |
| Answers, from the question text | 18/18 | 15/15 |
| `matches_canon` flag / note | 15/15 · 2/2 | 13/13 · 2/2 |
| Leak review items (exact set per record) | 3/3 | 2/2 |

Correct = status, knowledge state, acquisition route and evidence ids all equal the gold (for
who-knows: the set of characters; for when-learned: the story point; for leaks: the exact set of
(character, action passage, establishing passage)). Held-out by kind: knows 13/13, who-knows
1/1, when-learned 1/1, leak check 2/2; by state: KNOWS 5/5, BELIEVES 2/2, UNAWARE_IN_TEXT 1/1,
MISREMEMBERS 1/1, AUTHOR_CONFIRMED_UNAWARE 1/1, and 3/3 of the questions whose right answer is
"no state" (UNKNOWN or CONFLICT).

### The held-out miss, reviewed

| Miss | Class | Cause | Disposition |
|---|---|---|---|
| In `kh08`, "Mara told Iven that she hid the key." (Chapter 3, after "Edda watched Mara hide the key." in Chapter 2): the event for Iven had an unresolved proposition subject instead of Mara | extractor (**a real defect**) | "she" had two candidates, Mara (this sentence) and Edda (named in the sentence before), and the rule treated them as equal. Not guessing was the right default; preferring a candidate named earlier in the *same* sentence when it is the only one was the missing rule. The question set still passed because the unresolved event did not change who knows at Chapter 2 | **Post-hoc fix**, with two unit tests on new sentences (one where it resolves, one where two women are named in the same sentence and it stays unresolved). Not re-run on held-out |

Other changes after the run, none from a held-out result: a continuity check for *knowing,
then recorded as unaware* (CONFLICT, both passages); `kStoryPipelineVersion` and a test that
the same inputs give identical output; readable default labels for timeline ids. Before the
run, my own probe sentences and unit tests found and fixed: `sameEntity(null, null)` was false,
which broke "belief contradicts canon" for any state with no object; a negated or hedged
"told" wrongly recorded the clause; "was open" tagged `open` as a verb; a story point
phrase swallowed "in the cellar"; and one dev label (kd08) that said null where the story
did contradict the belief.

### What these numbers do not show

Everything in [the earlier list](#what-these-numbers-do-not-show) applies, and more:

- **17 held-out records, 17 questions.** One mistake is 6 points. Each phenomenon appears once
  or twice.
- **Written by the author of the rules**, after reading the handover, so the held-out set tests
  the design I already had, not the cases a different reader would think of.
- **Routes and states not in the held-out set**: OVERHEARD, READ, INFERRED and SUSPECTS appear
  only in the dev set, so their held-out score is untested.
- **The leak check implements one pattern** (a hiding or placement, then another character
  acting on that object or place). Two of two on a rule written for exactly that pattern says
  nothing about leaks in general; false-positive rate on a real manuscript is unknown.
- **No flashbacks, unreliable narrators or non-linear timelines**, which the handover names as
  reasons a flag may be wrong. The timeline here is a given order.
- **No real manuscript, no browser, no author reading the answers.**

### Answer to the handover's question 4: what examples and tests are needed

To *measure* each part, per part, with the part's own score (never one overall number):

| Part | Needed before trusting it | Exists |
|---|---|---|
| Tagging | A few hundred sentences of fiction not seen by the rule author, labelled by two people; per-label P/R/F1 | 55 records (story_v1); one author |
| Retrieval | A few hundred question/passage pairs from real manuscripts, including paraphrase, passive, pronouns and unanswerable questions | 55 records |
| Character knowledge | Per state × route × timeline shape (same scene, later scene, later chapter, flashback): at least ~20 each, from several authors' text; the false-belief and told-but-unconfirmed cases in particular | 38 records, ~1–3 per case |
| UNKNOWN handling | Questions whose honest answer is UNKNOWN *because* of each cause (silent, later acquisition, possibility, negation, ambiguity, no timeline point) with the cause as the label | Every cause has 1–3 cases |
| Continuity flags | Real drafts with author-marked true and false leaks; report precision (how many flags the author keeps) separately from recall | 5 synthetic cases, one pattern |

Track dataset version (`MANIFEST.json` hashes), schema version, `kStoryPipelineVersion` and
the commit with every result.
