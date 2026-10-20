/// How the character should sound, to this author, right now.
///
/// Phase 3.1 asks for *a relationship-voice composition service*, and 3.6 for
/// delivery that applies the relationship to *wording, warmth, challenge, humour
/// and vulnerability*, lets the same character answer differently early and late in
/// the project, refers to shared history only when relevant, avoids *creepy or
/// overly familiar phrasing*, and keeps relationship cues subtle.
///
/// This is that service, with one boundary drawn clearly: it composes a
/// [DeliveryStyle], a set of settings, and **writes no words**. Wording is the
/// language layer's (plan 2.3), and it will be handed this style. Keeping the two
/// apart is what lets the style be decided deterministically and tested, and the
/// wording be replaced without touching it.
///
/// ## What it combines
///
/// The stable voice, the evolving relationship, the passing mood and the behaviour
/// chosen for this turn. None of them is allowed to do another's work: the voice
/// says who the character is, the relationship how close they are, the mood how
/// they feel this minute, and the behaviour what they are doing with the turn.
///
/// ## Subtlety and history
///
/// Cue intensity is capped well below the top: familiarity is shown in small ways,
/// and more of it the closer they are, but never so much that a character who has
/// known the author a week talks as if they had known them for years. A reference
/// to something said before is allowed only when there is something relevant to
/// refer to, the two have talked more than once, and they are at least familiar.
library;

import 'package:authoros_core/procedural/generation_seed.dart';

import '../questions/relationship_stage.dart';
import 'relationship_behaviour.dart';
import 'relationship_state.dart';
import 'voice_profile.dart';

/// The settings the language layer is given to word one turn.
class DeliveryStyle {
  const DeliveryStyle({
    required this.behaviour,
    required this.tone,
    required this.vocabulary,
    required this.rhythm,
    required this.length,
    required this.warmth,
    required this.challenge,
    required this.humour,
    required this.vulnerability,
    required this.directness,
    required this.cueIntensity,
    required this.allowHistoryReference,
    required this.reluctant,
    required this.offersDoorway,
  });

  final RelationshipBehaviour behaviour;
  final VoiceTone tone;
  final VocabularyRegister vocabulary;
  final ConversationalRhythm rhythm;
  final CommunicationLength length;

  /// Each from zero to one.
  final double warmth;
  final double challenge;
  final double humour;
  final double vulnerability;
  final double directness;

  /// How much the relationship may show in the wording. Capped.
  final double cueIntensity;

  /// Whether the character may refer to something said before.
  final bool allowHistoryReference;

  /// The author insisted, and the character answers without enthusiasm.
  final bool reluctant;

  /// A closed conversation must offer a way into something else.
  final bool offersDoorway;
}

class RelationshipVoiceComposer {
  const RelationshipVoiceComposer();

  /// The most the relationship may show, however close. Below the top on purpose.
  static const double maxCueIntensity = 0.75;

  /// The least a relationship must have shared before the character speaks of
  /// earlier conversations.
  static const int sessionsBeforeHistory = 2;

  DeliveryStyle compose({
    required VoiceProfile voice,
    required AuthorCharacterRelationship relationship,
    required BehaviourChoice choice,
    EmotionalState mood = EmotionalState.calm,
    bool relevantHistory = false,
  }) {
    final closeness = relationship.closeness;
    final familiarity = relationship.score(RelationshipDimension.familiarity);
    final trust = relationship.score(RelationshipDimension.trust);
    final openness = relationship.score(RelationshipDimension.openness);
    final willing = relationship.score(
      RelationshipDimension.challengeWillingness,
    );

    var warmth =
        0.35 * voice.affection.value +
        0.35 * closeness +
        switch (voice.tone) {
          VoiceTone.warm => 0.15,
          VoiceTone.gentle => 0.10,
          VoiceTone.earnest => 0.05,
          VoiceTone.neutral || VoiceTone.formal => 0.0,
          VoiceTone.playful => 0.10,
          VoiceTone.timid => 0.05,
          VoiceTone.quiet => 0.0,
          VoiceTone.dry || VoiceTone.stoic => -0.05,
          VoiceTone.blunt || VoiceTone.sardonic => -0.10,
        };
    var humour = voice.humour.value * (0.5 + 0.5 * familiarity);
    var vulnerability = voice.openness.value * (0.4 * openness + 0.6 * trust);
    var challenge = voice.challengeLevel.value * (0.4 + 0.6 * willing);
    final directness =
        (0.6 * voice.confidence.value +
                switch (voice.tone) {
                  VoiceTone.blunt => 0.30,
                  VoiceTone.sardonic => 0.15,
                  VoiceTone.gentle || VoiceTone.quiet => -0.10,
                  VoiceTone.timid => -0.20,
                  VoiceTone.formal => -0.05,
                  _ => 0.0,
                } +
                0.2)
            .clamp(0.0, 1.0);

    switch (mood) {
      case EmotionalState.calm:
        break;
      case EmotionalState.guarded:
        warmth -= 0.2;
        vulnerability *= 0.3;
      case EmotionalState.vulnerable:
        vulnerability += 0.2;
        warmth += 0.1;
      case EmotionalState.irritated:
        warmth -= 0.2;
        challenge += 0.15;
      case EmotionalState.playful:
        humour += 0.2;
        warmth += 0.1;
    }

    // What the behaviour itself asks for.
    switch (choice.behaviour) {
      case RelationshipBehaviour.challenge || RelationshipBehaviour.correct:
        challenge = challenge < 0.5 ? 0.5 : challenge;
      case RelationshipBehaviour.tease || RelationshipBehaviour.humour:
        humour = humour < 0.5 ? 0.5 : humour;
      case RelationshipBehaviour.vulnerability:
        vulnerability = vulnerability < 0.5 ? 0.5 : vulnerability;
      case _:
        break;
    }

    // A new relationship is gentle about disagreement, even when the character is
    // not: they have not earned the right to push hard yet.
    if (relationship.stage == RelationshipStage.newStage) {
      challenge = challenge > 0.55 ? 0.55 : challenge;
    }

    double unit(double v) => v.clamp(0.0, 1.0);
    final cue = (closeness * 0.8).clamp(0.0, maxCueIntensity);
    return DeliveryStyle(
      behaviour: choice.behaviour,
      tone: voice.tone,
      vocabulary: voice.vocabulary,
      rhythm: voice.rhythm,
      length: voice.communicationLength,
      warmth: unit(warmth),
      challenge: unit(challenge),
      humour: unit(humour),
      vulnerability: unit(vulnerability),
      directness: directness,
      cueIntensity: cue,
      allowHistoryReference:
          relevantHistory &&
          relationship.stage.index >= RelationshipStage.familiar.index &&
          relationship.sharedSessions >= sessionsBeforeHistory,
      reluctant: choice.reluctant,
      offersDoorway: choice.doorway != null,
    );
  }
}

/// Which of a character's speech patterns were used lately, so none becomes a
/// catchphrase (plan 3.2: *character-specific speech patterns without repetitive
/// catchphrases*).
class SpeechPatternTracker {
  const SpeechPatternTracker([this.lastUsed = const {}]);

  /// The turn each pattern was last used on.
  final Map<String, int> lastUsed;

  /// A pattern not used within [cooldown] turns, or null when none is due.
  ///
  /// No pattern of any kind is used on two turns running, whatever the cooldown:
  /// two habits of speech back to back read as a tic as much as one repeated.
  /// And not every turn gets one. Roughly one turn in [oneIn] does, chosen with
  /// the seed.
  String? next(
    VoiceProfile voice, {
    required int turn,
    required GenerationSeed seed,
    int cooldown = 4,
    int oneIn = 3,
  }) {
    if (voice.speechPatterns.isEmpty) return null;
    if (lastUsed.isNotEmpty &&
        turn - lastUsed.values.reduce((a, b) => a > b ? a : b) <= 1) {
      return null;
    }
    final roll = seed.derive('pattern/$turn').unitAt(turn, 7);
    if (roll > 1 / oneIn) return null;
    final due = [
      for (final p in voice.speechPatterns)
        if (turn - (lastUsed[p] ?? -1000) > cooldown) p,
    ];
    if (due.isEmpty) return null;
    final ordered = [...due]..sort();
    return ordered[(seed.derive('pattern-pick/$turn').unitAt(turn, 3) *
            ordered.length)
        .floor()
        .clamp(0, ordered.length - 1)];
  }

  SpeechPatternTracker used(String pattern, int turn) =>
      SpeechPatternTracker({...lastUsed, pattern: turn});
}
