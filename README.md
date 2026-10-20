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

## Adding a model

The seams are `DeliveryService` and `ResponseReader`. A model-backed
implementation would implement them here, behind the same guarantees (the question
verbatim, only supplied facts, fall back to the rule-based line). It is a separate
decision with its own privacy design (Companion ADR-0001), not part of this
package yet.

## Checks

```
dart format --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```
