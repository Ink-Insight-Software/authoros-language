/// What a model is asked when it words one turn, and how a reply is turned back
/// into a [Dialogue].
///
/// The prompt carries only what the turn needs: the character's voice, what this
/// moment is, what the author just said, the facts the character may refer to, and
/// the question the engine selected. Nothing else from the project is in it. An
/// application shows [DeliveryPrompt.build]'s `preview` to the author before the
/// first request leaves the device.
library;

import '../language/delivery_service.dart';
import '../questions/relationship_stage.dart';
import '../voice/relationship_behaviour.dart';
import '../voice/voice_profile.dart';
import 'model_client.dart';

class DeliveryPrompt {
  const DeliveryPrompt._();

  static const _system = '''
You write one line of speech for a fictional character, who is talking with the author who is creating them. The author is developing the character and the story, and the conversation is part of that. Stay in the character's voice.

Rules:
1. Include the QUESTION exactly as written, word for word, once, and make it the last thing you write.
2. Before it, write one to three short sentences at most: react to what the author just said (if anything), then lead into the question, in the character's own manner. Do not answer the question yourself.
3. State no fact about the character or the story that is not listed under KNOWN. Do not invent names, places, dates, numbers, relationships or events. If you are unsure, say less.
4. Write only what the character says. No quotation marks around it, no names or labels, no stage directions, no markdown, no emoji.''';

  /// The prompt for [r], and the words the character may use without checking
  /// them against the author's text: none. [characterName] is the character's own
  /// name, which the model may use.
  static ModelPrompt build(DeliveryRequest r, {String? characterName}) {
    final v = r.voice;
    final s = r.style;
    final b = StringBuffer();
    final name = characterName?.trim();
    if (name != null && name.isNotEmpty) b.writeln('CHARACTER: $name');
    b.writeln('VOICE');
    b.writeln('- Tone: ${v.tone.name}');
    b.writeln('- How much they say: ${_length(s.length)}');
    b.writeln('- Words: ${s.vocabulary.name}');
    b.writeln('- Rhythm: ${s.rhythm.name}');
    b.writeln(
      '- Energy: ${_level(v.energy)}; confidence: ${_level(v.confidence)}',
    );
    b.writeln('- Humour: ${_level(v.humour)}; warmth: ${_degree(s.warmth)}');
    b.writeln('- Directness: ${_degree(s.directness)}');
    b.writeln(
      '- Openness: ${_level(v.openness)}; defensiveness: ${_level(v.defensiveness)}',
    );
    final habits = [
      for (final p in v.speechPatterns)
        if (p.trim().isNotEmpty) p.trim(),
    ];
    if (habits.isNotEmpty) {
      b.writeln('- Habits of speech: ${habits.join('; ')}');
    }
    final notes = v.voiceNotes.trim();
    if (notes.isNotEmpty) {
      b.writeln('- The author\'s notes on the voice: $notes');
    }
    final examples = [
      for (final e in v.examples)
        if (e.trim().isNotEmpty) e.trim(),
    ];
    if (examples.isNotEmpty) {
      b.writeln('- Lines the author wrote in this voice:');
      for (final e in examples.take(4)) {
        b.writeln('  "$e"');
      }
    }
    b.writeln();
    b.writeln('THIS MOMENT');
    b.writeln('- What the character is doing: ${_behaviour(s.behaviour)}');
    b.writeln('- How well they know the author: ${_stage(r.stage)}');
    if (s.reluctant) {
      b.writeln('- The author insisted, so they answer without enthusiasm.');
    }
    final last = r.lastAuthorText?.trim() ?? '';
    b.writeln();
    b.writeln(
      last.isEmpty
          ? 'THE AUTHOR HAS NOT SAID ANYTHING YET'
          : 'THE AUTHOR JUST SAID\n$last',
    );
    b.writeln();
    b.writeln('KNOWN (the only facts you may refer to)');
    final facts = [
      for (final f in r.knownFacts)
        if (f.trim().isNotEmpty) f.trim(),
    ];
    if (facts.isEmpty) {
      b.writeln('- nothing');
    } else {
      for (final f in facts) {
        b.writeln('- $f');
      }
    }
    b.writeln();
    b.writeln('QUESTION\n${r.question}');
    return ModelPrompt(system: _system, user: b.toString().trimRight());
  }

  static String _level(VoiceLevel l) => switch (l) {
    VoiceLevel.veryLow => 'very low',
    VoiceLevel.low => 'low',
    VoiceLevel.medium => 'medium',
    VoiceLevel.high => 'high',
    VoiceLevel.veryHigh => 'very high',
  };

  static String _degree(double d) => d < 0.25
      ? 'very little'
      : d < 0.45
      ? 'a little'
      : d < 0.65
      ? 'moderate'
      : d < 0.85
      ? 'strong'
      : 'very strong';

  static String _length(CommunicationLength l) => switch (l) {
    CommunicationLength.terse => 'very little: a few words',
    CommunicationLength.measured => 'a sentence or two',
    CommunicationLength.expansive => 'a few sentences',
  };

  static String _behaviour(RelationshipBehaviour b) => switch (b) {
    RelationshipBehaviour.trust =>
      'asking openly, as someone who trusts the author',
    RelationshipBehaviour.tease => 'teasing the author as they ask',
    RelationshipBehaviour.challenge => 'pushing back on the author as they ask',
    RelationshipBehaviour.correct => 'correcting the author as they ask',
    RelationshipBehaviour.vulnerability =>
      'asking while showing a vulnerable side',
    RelationshipBehaviour.humour => 'asking lightly, with some humour',
    RelationshipBehaviour.deflect ||
    RelationshipBehaviour.redirect ||
    RelationshipBehaviour.withhold ||
    RelationshipBehaviour.refuse => 'asking',
  };

  static String _stage(RelationshipStage s) => switch (s) {
    RelationshipStage.newStage => 'barely: a stranger',
    RelationshipStage.familiar => 'somewhat',
    RelationshipStage.trusted => 'well',
    RelationshipStage.connected => 'very well',
    RelationshipStage.deeplyConnected => 'as one of the people closest to them',
  };
}
