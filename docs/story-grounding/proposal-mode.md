# Proposal mode

Grounded answering and creative suggestion are different jobs with different risks, so
they are different stages. Proposal mode is **off by default and entered on purpose**.

## The rules

1. **A proposal is not a fact.** It is a `Proposal`, held in a `ProposalLedger`. It is
   never put in the `StoryIndex`, so retrieval cannot answer from one, and the test
   suite asserts the index and its answers are unchanged after proposals are offered.
2. **Always labelled.** `Proposal.status` is `PROPOSED` and is part of the type, not a
   style choice: a UI that renders a proposal has the label in hand.
3. **Grounded.** A proposal must cite the exact story text that inspired it
   (`grounding`, with offsets) and say why (`rationale`). `ProposalGuard` refuses one
   that cites nothing, or cites text that is not in the story.
4. **No silent canon.** A proposal leaves the ledger only through `approve(id)`, which
   the author's explicit action calls, and which returns the text and its grounding for
   the existing canon path. Companion's canon path saves a copy and never changes the
   opened file.
5. **Contradiction is shown, not hidden.** A proposal that the story contradicts is
   reported as a conflict with the contradicting passage, and the author decides whether
   it is an intentional revision. (The grounded generator below never produces one;
   the guard hook for a generative one is `ProposalGuard.check`.)

## Entering

- **Default:** a question that the story does not answer returns `UNKNOWN`, and when the
  story is simply silent (`Answer.offerProposal == true`) the UI may show one quiet
  line: *"The text doesn't say. Want ideas?"*. Nothing is generated until the author
  chooses it.
- **Explicit:** the author may start a question in exploration mode (the handover's
  `"mode": "explore"`). The grounded result is still shown first, unchanged, then the
  proposals under it.
- **Not offered** when the story *does* say something that doesn't settle the question
  (a possibility, a thing that was moved later, an ambiguous pronoun): there the useful
  thing is the evidence, and `offerProposal` is false.

## Displaying

Two separate areas, never one list: **"What the story says"** (the `Answer`: status,
answer, quoted evidence with a link to the passage) and **"Ideas"** (proposals). A
proposal shows the PROPOSED label, the idea worded as an idea ("Maybe it is …"), the
quoted story text that inspired it, and the reasoning. A proposal is never styled like
an answer and never appears inside an answer's evidence list. For a person using a
screen reader the label is read first.

## Accepting, editing, rejecting

- **Accept** → `ProposalLedger.approve(id)` returns an `ApprovedProposal` (text, the
  question it answered, grounding). The caller records the author's approval time and
  the destination record, then saves through Companion's discovery → canon path. Only
  from that point is it canon, and then it is an ordinary passage with
  `SourceKind.canon`.
- **Edit** → the author changes the wording first; the edited text, not the generated
  one, is what is approved. The grounding stays attached.
- **Reject** → `reject(id)`; it is not offered again for that question in this session.

## Storing

The ledger is separate from the index, the manuscript and canon. Whether proposals
persist between sessions is a product decision: if they do, they go in their own store
with `status: PROPOSED`, the project id, the grounding, and a creation time, and are
never merged into facts. Nothing in this repo writes to disk.

## What exists

`GroundedProposalGenerator` proposes only from what the story already contains: for a
missing place it offers places the story already names (most recently mentioned first),
each citing the passage that names it. It never invents a new place, character or event.
That is the safe floor; a generative `ProposalGenerator` (including the project's own
model, once trained) can offer richer ideas, subject to the same guard and the same
ledger.

For example, with the passages "Mara hid the key beneath the chapel floor." and
"Iven walked to the market.", the question "Where is the sword?" is `UNKNOWN` with
`offerProposal: true`, and exploration mode returns (this is the real output shape):

```json
{
  "query": "Where is the sword?",
  "mode": "explore",
  "grounded_result": { "status": "UNKNOWN", "note": null, "evidence_ids": [] },
  "proposals": [{
    "id": "p_item_sword_place_market",
    "text": "Maybe it is in the market.",
    "status": "PROPOSED",
    "inspiration": ["Iven walked to the market."],
    "reasoning": "The story already mentions the market.",
    "requires_author_approval": true }]
}
```

The handover's other example, *"Could someone have seen Mara hide the key?"* with the
idea of a chapel caretaker, needs a **generative** proposer: the grounded generator
only answers "where" questions from places the story already names, so it offers
nothing for "who saw". That generator is not built; it would implement
`ProposalGenerator` and be subject to the same guard and ledger.

## What leaves the device

With the grounded generator, nothing. If a model-backed generator is added, the
request contains only the passages named as grounding plus the question, and the UI
states that before the first use and on every use that sends a new passage. The model
runs on the project owner's own server (decision recorded this session) or on the
device; an external AI service is not part of the design, and if one were ever
considered the handover's rule applies: document exactly what text leaves the device and
make that choice visible to the author.
