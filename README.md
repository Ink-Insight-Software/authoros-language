# authoros_language

**The shared AuthorOS language layer, and its one copy.** How a character is
worded, and how an author's free text is read. It moved here from
`companion/engine/` in `Ink-Insight-Software/AuthorOS-Expansions`, unchanged.
AOS Companion depends on it, pinned by commit; none of the applications keeps a
copy.

It is rule-based, deterministic and on-device. No model, no network, nothing
sent anywhere. Every line a character can add is authored and public through
`RuleBasedDelivery.phrases` and `Listening.phrases`, so a reviewer can read all
of what a character may say.

## What is in it

| Area | What it does |
|---|---|
| `DeliveryService` / `RuleBasedDelivery` | Puts a decided question in a character's mouth. The question is placed word for word; nothing is said that is not a bank line, the question, the author's own words or a supplied fact. |
| `Listening`, `Lexicon` | Acknowledges what the author just said: the feeling, person, event or place they named, a callback to something said before, a remark on the kind of feeling. |
| `MannerBanks`, `MannerShared` | A bank of lines for each tone: warm, gentle and earnest share one, neutral has one, and sardonic, dry, blunt, formal, timid, quiet, playful and stoic each have their own. |
| `ResponseReader` | Reads free text for uncertainty, correction, disagreement, several possibilities, a question back, and the fears, wants and values it mentions. |
| `CharacterAnswerer` | Lets a character answer when the author asks them something, only from what is supplied. |
| `VoiceSample` | A short sample of how a voice sounds, for an editor to show. |
| The vocabulary | `VoiceProfile`, `RelationshipStage`, `RelationshipBehaviour`, `RelationshipVoiceComposer`, `TopicAccess` and the types they need. |

## Using it

Depend on a commit, never a branch, so a change here reaches an application only
when that application moves its pin:

```yaml
dependencies:
  authoros_language:
    git:
      url: https://github.com/Ink-Insight-Software/authoros-language.git
      ref: <commit> # 0.1.0
```

## The model-backed delivery

`ModelBackedDelivery` words a turn with a model, behind the same seam as the
rule-based delivery, and is **off unless an application turns it on**. It is a
separate decision from the rule-based layer (Companion ADR-0001), with its own
privacy design:

- **Only a turn that asks a question is worded by a model.** Opening a
  conversation, closing a topic and answering back stay rule-based; they are
  decided and bounded already.
- **Only what the turn needs is sent**, and `DeliveryPrompt.build(...).preview` is
  exactly that text, for an application to show the author before the first request
  leaves the device: the character's voice (including the author's own notes and
  example lines for it), what the character is doing, the author's last words, the
  facts the character may refer to, and the selected question. Nothing else from
  the project.
- **The question is never rewritten.** `DeliveryGuard` checks every reply: the
  question must be intact, once, last; the reply short and plain; and no name,
  place or number may appear that the model was not given. A reply that fails any
  check is thrown away.
- **There is always a floor.** On a failed check, a refused key, a limit, a timeout
  or no network, the rule-based line is used, and `DeliveryResult.fallback` says
  why.
- **A reply is a suggestion, never canon.** The guard cannot prove a sentence is true
  of the story, so the prompt allows no facts but those supplied, and nothing a model
  says becomes canon without the author's explicit approval.
- **The key is the author's own**, held by the application and sent only as the
  request header. `AnthropicClient` never stores, logs or returns it.
- **Not deterministic.** A model's wording is not replayable from a seed; the
  rule-based delivery still is.

Another provider implements `ModelClient` (text in, text out) and changes nothing
else.

## Checks

```
dart format --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```
