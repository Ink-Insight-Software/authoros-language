# Changelog

## 0.2.0

- **Model-backed delivery, off by default.** `ModelBackedDelivery` (an
  `AsyncDeliveryService`), `DeliveryPrompt` (what is sent, with a preview),
  `DeliveryGuard` (the question intact, short and plain, no new name, place or
  number), `ModelClient` and an `AnthropicClient` that uses the author's own key.
  A rejected reply, a failure or no network falls back to the rule-based line.
  Additive: nothing existing changes. Adds a dependency on `http`.

## 0.1.0

- **Moved in from AOS Companion's engine, unchanged.** The rule-based language
  layer (delivery, listening, reading, answering, the tone banks and the voice
  sample) and the vocabulary it speaks in (voice profile, relationship stage and
  behaviour, topic access, the author response analysis). Tests that need only
  these moved with them; tests that also need Companion's project, journal or
  conversation stay there.
