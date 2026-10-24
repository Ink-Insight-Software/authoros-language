# Changelog

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
