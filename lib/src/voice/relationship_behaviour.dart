/// What the character does with what the author says or asks.
///
/// Phase 3.4 lists ten ways a character can respond (trust and answer, tease,
/// deflect, challenge, redirect, withhold, show vulnerability, use humour, correct,
/// refuse) and asks that the choice come from *personality + relationship + topic +
/// current context*, that a character may disagree and ask the author to justify a
/// choice, that there be neither *constant agreement or constant confrontation*, and
/// that a refusal or deflection *still offer a useful conversational doorway.*
///
/// This is that choice, made deterministically from numbers the rest of the engine
/// already holds: the voice, the relationship, how guarded the topic is, the
/// passing mood, what has just been done, and a seed. It picks a behaviour and says
/// why. It does not say anything; wording a behaviour is delivery (plan 2.3).
///
/// ## The three guards
///
/// - **Boundaries only ever close a conversation, never a record.** A topic the
///   character is not yet willing to discuss produces deflect, redirect, withhold or
///   refuse, always with a doorway to something they will talk about. Nothing here
///   sees the author's records.
/// - **Variety is enforced, not hoped for.** A behaviour just used is less likely;
///   three plain answers in a row are never followed by a fourth, and nor are three
///   pushes (challenge, correct, withhold, refuse), whenever there is anything else
///   the character could do.
/// - **The author can insist.** A character can be reluctant and still answer.
library;

import 'package:authoros_core/procedural/generation_seed.dart';

import 'disagreement.dart';
import 'relationship_state.dart';
import 'topic_boundaries.dart';
import 'voice_profile.dart';

/// The ten ways to respond.
enum RelationshipBehaviour {
  /// Answer openly.
  trust,
  tease,
  deflect,
  challenge,
  redirect,
  withhold,
  vulnerability,
  humour,
  correct,
  refuse;

  /// Whether this closes a conversation, so it must offer a doorway.
  bool get closes =>
      this == deflect || this == redirect || this == withhold || this == refuse;

  /// Whether this pushes against the author, counted when avoiding a run of it.
  bool get pushes =>
      this == challenge ||
      this == correct ||
      this == refuse ||
      this == withhold;
}

/// How the character feels just now. Passing, and not stored: unlike the voice
/// and the relationship, it belongs to a moment (plan 2.7: *separate stable
/// personality from temporary emotional state*).
enum EmotionalState { calm, guarded, vulnerable, irritated, playful }

/// The last few behaviours, newest last.
class BehaviourHistory {
  const BehaviourHistory([this.recent = const []]);

  final List<RelationshipBehaviour> recent;

  BehaviourHistory add(RelationshipBehaviour behaviour, {int keep = 12}) {
    final next = [...recent, behaviour];
    return BehaviourHistory(
      next.length > keep ? next.sublist(next.length - keep) : next,
    );
  }

  /// The last [count] behaviours, newest first.
  List<RelationshipBehaviour> last(int count) => [
    for (final b in recent.reversed.take(count)) b,
  ];
}

/// The behaviour chosen, and what it needs.
class BehaviourChoice {
  const BehaviourChoice({
    required this.behaviour,
    required this.reasons,
    this.doorway,
    this.reluctant = false,
  });

  final RelationshipBehaviour behaviour;

  /// Plain sentences of why, for tests and for explaining a choice.
  final List<String> reasons;

  /// The deepest topic the character will discuss, offered when this closes a
  /// conversation. Set whenever [behaviour] closes one.
  final TopicAccess? doorway;

  /// The author insisted and the character will, but not gladly.
  final bool reluctant;
}

class BehaviourSelector {
  const BehaviourSelector();

  /// The behaviour for this turn.
  BehaviourChoice choose({
    required VoiceProfile voice,
    required AuthorCharacterRelationship relationship,
    required TopicAccess access,
    required GenerationSeed seed,
    required int turn,
    EmotionalState mood = EmotionalState.calm,
    BehaviourHistory history = const BehaviourHistory(),
    Disagreement? disagreement,
    bool authorInsists = false,
  }) {
    final stage = relationship.stage;
    final decision = CharacterBoundaries.decide(
      access,
      stage,
      authorInsists: authorInsists,
    );
    final weights = <RelationshipBehaviour, double>{};
    final reasons = <RelationshipBehaviour, List<String>>{};

    void add(RelationshipBehaviour b, double weight, String why) {
      if (weight <= 0) return;
      weights[b] = (weights[b] ?? 0) + weight;
      (reasons[b] ??= []).add(why);
    }

    final defensive = voice.defensiveness.value;
    final humour = voice.humour.value;
    final openness = voice.openness.value;
    final challengeLevel = voice.challengeLevel.value;
    final willingToChallenge = relationship.score(
      RelationshipDimension.challengeWillingness,
    );
    final familiarity = relationship.score(RelationshipDimension.familiarity);
    final trust = relationship.score(RelationshipDimension.trust);
    final familiar = stage.index >= 1;

    if (!decision.willing) {
      // A closed topic: some way of closing it, and always a doorway.
      if (decision.shortfall <= 1) {
        add(
          RelationshipBehaviour.deflect,
          1.0 + 0.5 * defensive,
          'the topic is a little beyond how well they know each other',
        );
        add(
          RelationshipBehaviour.redirect,
          1.0 + 0.5 * (1 - defensive),
          'a warmer character turns it toward something easier',
        );
        add(
          RelationshipBehaviour.withhold,
          0.3 + 0.3 * defensive,
          'they would rather keep it for now',
        );
      } else {
        add(
          RelationshipBehaviour.withhold,
          1.0,
          'the topic is well beyond the relationship so far',
        );
        add(
          RelationshipBehaviour.refuse,
          1.2 * defensive + (access == TopicAccess.protectedTopic ? 0.6 : 0),
          'a guarded character, or a protected topic',
        );
        add(RelationshipBehaviour.deflect, 0.6, 'turning it aside');
        add(RelationshipBehaviour.redirect, 0.5, 'offering something else');
      }
    } else if (disagreement != null) {
      // The author has proposed something the character does not recognise.
      final strength = disagreement.strength;
      add(
        RelationshipBehaviour.challenge,
        0.8 * challengeLevel + 0.8 * willingToChallenge + strength,
        'the proposal runs against "${disagreement.evidence}"',
      );
      add(
        RelationshipBehaviour.correct,
        strength >= 0.6 ? strength + 0.4 * willingToChallenge : 0,
        'it conflicts with something firmly recorded',
      );
      add(
        RelationshipBehaviour.trust,
        0.25 + 0.5 * (1 - challengeLevel),
        'the character may let it stand',
      );
    } else {
      // A plain answer is the baseline, but a tender topic is not just answered:
      // the character has more to bring to it than that.
      final tender = access.index >= TopicAccess.sensitive.index;
      add(
        RelationshipBehaviour.trust,
        tender ? 0.6 : 1.0,
        'answering the author plainly',
      );
      if (familiar) {
        add(
          RelationshipBehaviour.tease,
          1.2 * humour * familiarity,
          'they know each other well enough to tease',
        );
        add(
          RelationshipBehaviour.challenge,
          0.9 * challengeLevel * willingToChallenge,
          'asking the author to justify a choice',
        );
      }
      // A floor, so even a deadpan character has a light moment to turn to and a
      // run of plain answers can always be broken without changing the subject.
      add(
        RelationshipBehaviour.humour,
        0.1 + 0.7 * humour,
        'a light moment, as much as this character allows',
      );
      if (tender && stage.index >= 2) {
        add(
          RelationshipBehaviour.vulnerability,
          2.0 * openness * trust,
          'trusted enough to say something true about themselves',
        );
      }
      add(
        RelationshipBehaviour.deflect,
        0.3 * defensive,
        'a defensive character sometimes turns a question aside',
      );
      add(RelationshipBehaviour.redirect, 0.2, 'changing the subject');
    }

    // The passing mood nudges what is already possible.
    void scale(RelationshipBehaviour b, double factor) {
      if (weights.containsKey(b)) weights[b] = weights[b]! * factor;
    }

    switch (mood) {
      case EmotionalState.calm:
        break;
      case EmotionalState.guarded:
        scale(RelationshipBehaviour.trust, 0.7);
        scale(RelationshipBehaviour.vulnerability, 0.3);
        add(
          RelationshipBehaviour.deflect,
          decision.willing ? 0.5 : 0,
          'guarded just now',
        );
      case EmotionalState.vulnerable:
        scale(RelationshipBehaviour.vulnerability, 1.6);
        scale(RelationshipBehaviour.tease, 0.5);
      case EmotionalState.irritated:
        scale(RelationshipBehaviour.challenge, 1.4);
        scale(RelationshipBehaviour.refuse, 1.3);
        scale(RelationshipBehaviour.tease, 0.6);
      case EmotionalState.playful:
        scale(RelationshipBehaviour.tease, 1.5);
        scale(RelationshipBehaviour.humour, 1.5);
    }

    // Variety: a behaviour just used is a little less likely, newest most of all.
    // Gentle on purpose. The hard limits below are what guarantee variety; this
    // only keeps one behaviour from crowding the others, and leaves personality
    // and mood room to decide how often a character jokes, or pushes, or opens up.
    const recency = [1.0, 0.6, 0.3];
    final recent = history.last(3);
    for (var i = 0; i < recent.length; i++) {
      scale(recent[i], 1 - 0.3 * recency[i]);
    }
    // Freshness: something the character has not done lately is a little more
    // likely, so a long conversation shows the range this character has rather
    // than the one or two things that happen to score highest each turn.
    final lately = history.last(6).toSet();
    for (final b in weights.keys.toList()) {
      if (!lately.contains(b)) scale(b, 1.25);
    }
    // Neither constant agreement nor constant confrontation (plan 3.4). A run of
    // two pushes in four makes more of it less likely; a run of three of either
    // kind is not continued at all, as long as there is anything else to do.
    final window = history.last(4);
    if (window.where((b) => b.pushes).length >= 2) {
      for (final b in RelationshipBehaviour.values.where((b) => b.pushes)) {
        scale(b, 0.4);
      }
    }
    if (recent.length == 3) {
      if (recent.every((b) => b == RelationshipBehaviour.trust) &&
          weights.keys.any((b) => b != RelationshipBehaviour.trust)) {
        weights.remove(RelationshipBehaviour.trust);
        reasons.remove(RelationshipBehaviour.trust);
      }
      if (recent.every((b) => b.pushes) && weights.keys.any((b) => !b.pushes)) {
        weights.removeWhere((b, _) => b.pushes);
      }
    }

    // The highest weight wins, with a seeded tie-break so a turn replays.
    final turnSeed = seed.derive('behaviour/$turn');
    RelationshipBehaviour? best;
    var bestWeight = -1.0;
    var index = 0;
    for (final b in RelationshipBehaviour.values) {
      final w = weights[b];
      index++;
      if (w == null) continue;
      final jittered = w + turnSeed.unitAt(index, 0) * 1e-6;
      if (jittered > bestWeight) {
        bestWeight = jittered;
        best = b;
      }
    }
    final chosen = best ?? RelationshipBehaviour.trust;
    return BehaviourChoice(
      behaviour: chosen,
      reasons: reasons[chosen] ?? const ['answering the author plainly'],
      doorway: chosen.closes ? decision.willingUpTo : null,
      reluctant: decision.reluctant,
    );
  }
}
