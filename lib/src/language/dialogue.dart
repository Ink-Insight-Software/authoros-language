/// What a character says in one turn (plan 2.3).
///
/// The language layer takes the engine's decisions (which question, what the
/// character is doing with the moment, how it should sound) and returns a
/// [Dialogue]: a few short lines, each marked for what it is, so the app can show a
/// reaction beat and a question differently without parsing prose.
library;

import '../voice/relationship_behaviour.dart';

enum LineKind {
  /// A short beat reacting to what the author just said.
  reaction,

  /// The character answering a question the author put to them.
  answer,

  /// Introduces what is coming: "Humour me for a second."
  lead,

  /// The question itself, word for word as selected.
  question,

  /// Something the character remembers, from supplied facts only.
  memory,

  /// A way into something else, after the character closed a topic.
  doorway,

  /// The character declining or deflecting.
  closing,

  /// A habit of theirs: a tease, a dodge, a pause.
  quirk,

  /// A remark on what the author said: about a kind of feeling, or that something
  /// has come up before. Stock wording, asserting nothing about the story.
  reflection,

  /// How a conversation opens: hello, or welcome back, and what is open.
  greeting,
}

class DialogueLine {
  const DialogueLine(this.kind, this.text);

  final LineKind kind;
  final String text;
}

class Dialogue {
  const Dialogue({
    required this.lines,
    required this.behaviour,
    this.question,
    this.fragments = const [],
    this.referencedFacts = const [],
  });

  final List<DialogueLine> lines;
  final RelationshipBehaviour behaviour;

  /// The selected question, exactly as given. Null when the character closed the
  /// topic instead of asking. This is the guarantee that wording never changes
  /// what was asked.
  final String? question;

  /// The ids of the phrases used, for the caller to keep so the same wording is not
  /// reached for again soon.
  final List<String> fragments;

  /// The supplied facts the dialogue drew on. Always a subset of what was passed
  /// in, never anything invented.
  final List<String> referencedFacts;

  bool get asksQuestion => question != null;

  /// This dialogue with [answer] said first: the character replies to what the
  /// author asked, then carries on.
  Dialogue withAnswer(List<String> answer) => answer.isEmpty
      ? this
      : Dialogue(
          lines: [
            for (final a in answer) DialogueLine(LineKind.answer, a),
            ...lines,
          ],
          behaviour: behaviour,
          question: question,
          fragments: fragments,
          referencedFacts: referencedFacts,
        );

  /// This dialogue with a quirk's [lines] said after any reaction and before the
  /// rest, so the character reacts, has their moment, and then goes on.
  Dialogue withQuirk(List<String> quirkLines) {
    if (quirkLines.isEmpty) return this;
    var at = 0;
    while (at < lines.length && lines[at].kind == LineKind.reaction) {
      at++;
    }
    return Dialogue(
      lines: [
        ...lines.sublist(0, at),
        for (final q in quirkLines) DialogueLine(LineKind.quirk, q),
        ...lines.sublist(at),
      ],
      behaviour: behaviour,
      question: question,
      fragments: fragments,
      referencedFacts: referencedFacts,
    );
  }

  /// The lines as plain text, one per line, for tests and plain-text display.
  String get text => lines.map((l) => l.text).join('\n');
}
