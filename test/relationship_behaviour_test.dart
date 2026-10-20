/// What a character does with the author: answer, tease, deflect, challenge,
/// redirect, withhold, open up, joke, correct or refuse.
///
/// Phase 3.4 of the master build plan, and the behaviour cases of 3.9: deflection,
/// refusal, vulnerability and challenge, a character who can disagree, a refusal
/// that always offers a doorway, and neither constant agreement nor constant
/// confrontation. Each test builds the voice and relationship it needs, so it fails
/// for the rule it names.
library;

import 'package:authoros_core/procedural/generation_seed.dart';
import 'package:authoros_language/authoros_language.dart';
import 'package:test/test.dart';

const selector = BehaviourSelector();

VoiceProfile voice({
  VoiceLevel humour = VoiceLevel.medium,
  VoiceLevel openness = VoiceLevel.medium,
  VoiceLevel defensiveness = VoiceLevel.medium,
  VoiceLevel challenge = VoiceLevel.medium,
}) => VoiceProfile(
  projectId: 'p',
  characterId: 'kali',
  humour: humour,
  openness: openness,
  defensiveness: defensiveness,
  challengeLevel: challenge,
);

/// A relationship standing at [stage], with the other dimensions set to suit.
AuthorCharacterRelationship at(RelationshipStage stage, {double? willing}) {
  final (familiarity, trust, openness, sessions) = switch (stage) {
    RelationshipStage.newStage => (0.0, 0.0, 0.1, 0),
    RelationshipStage.familiar => (0.4, 0.3, 0.3, 3),
    RelationshipStage.trusted => (0.6, 0.6, 0.5, 8),
    RelationshipStage.connected => (0.8, 0.8, 0.7, 12),
    RelationshipStage.deeplyConnected => (0.95, 0.95, 0.95, 12),
  };
  final r = AuthorCharacterRelationship(
    projectId: 'p',
    characterId: 'kali',
    scores: {
      RelationshipDimension.familiarity: familiarity,
      RelationshipDimension.trust: trust,
      RelationshipDimension.openness: openness,
      RelationshipDimension.challengeWillingness: ?willing,
    },
    sharedSessions: sessions,
  );
  expect(r.stage, stage, reason: 'the helper must build the stage it names');
  return r;
}

BehaviourChoice choose(
  VoiceProfile voice,
  AuthorCharacterRelationship relationship,
  TopicAccess access, {
  int seed = 1,
  int turn = 0,
  EmotionalState mood = EmotionalState.calm,
  BehaviourHistory history = const BehaviourHistory(),
  Disagreement? disagreement,
  bool insists = false,
}) => selector.choose(
  voice: voice,
  relationship: relationship,
  access: access,
  seed: GenerationSeed.root(seed),
  turn: turn,
  mood: mood,
  history: history,
  disagreement: disagreement,
  authorInsists: insists,
);

/// [turns] consecutive choices, each carrying the history of the ones before it,
/// as a real conversation does.
List<RelationshipBehaviour> simulate(
  VoiceProfile voice,
  AuthorCharacterRelationship relationship,
  TopicAccess access, {
  int turns = 80,
  int seed = 1,
  EmotionalState mood = EmotionalState.calm,
}) {
  var history = const BehaviourHistory();
  final out = <RelationshipBehaviour>[];
  for (var turn = 0; turn < turns; turn++) {
    final c = choose(
      voice,
      relationship,
      access,
      seed: seed,
      turn: turn,
      mood: mood,
      history: history,
    );
    history = history.add(c.behaviour);
    out.add(c.behaviour);
  }
  return out;
}

Disagreement disagreement({double strength = 0.7}) => Disagreement(
  commitment: const CharacterCommitment(
    id: 'loyal',
    kind: CommitmentKind.value,
    statement: 'Kali never abandons anyone who trusted her.',
    avoids: {'abandon'},
  ),
  matchedTerms: const {'abandon'},
  strength: strength,
);

void main() {
  group('a topic the character will not take up yet', () {
    test(
      'is closed with a deflection, a redirect or a withholding, and a doorway',
      () {
        for (var seed = 1; seed <= 40; seed++) {
          final c = choose(
            voice(),
            at(RelationshipStage.newStage),
            TopicAccess.sensitive,
            seed: seed,
          );
          expect({
            RelationshipBehaviour.deflect,
            RelationshipBehaviour.redirect,
            RelationshipBehaviour.withhold,
          }, contains(c.behaviour));
          expect(
            c.doorway,
            TopicAccess.personal,
            reason: 'a closed topic always offers something they will discuss',
          );
        }
      },
    );

    test('does not go so far as refusing when it is only a stage away', () {
      for (var seed = 1; seed <= 40; seed++) {
        expect(
          choose(
            voice(defensiveness: VoiceLevel.veryHigh),
            at(RelationshipStage.newStage),
            TopicAccess.sensitive,
            seed: seed,
          ).behaviour,
          isNot(RelationshipBehaviour.refuse),
        );
      }
    });

    test('a guarded character refuses a protected topic outright', () {
      final c = choose(
        voice(defensiveness: VoiceLevel.veryHigh),
        at(RelationshipStage.newStage),
        TopicAccess.protectedTopic,
      );
      expect(c.behaviour, RelationshipBehaviour.refuse);
      expect(c.doorway, isNotNull);
    });

    test('an open character withholds rather than refuses', () {
      final c = choose(
        voice(defensiveness: VoiceLevel.veryLow),
        at(RelationshipStage.newStage),
        TopicAccess.protectedTopic,
      );
      expect(c.behaviour, RelationshipBehaviour.withhold);
    });

    test('a warm character turns it toward something easier', () {
      final warm = voice(defensiveness: VoiceLevel.veryLow);
      final guarded = voice(defensiveness: VoiceLevel.veryHigh);
      final r = at(RelationshipStage.newStage);
      expect(
        choose(warm, r, TopicAccess.sensitive).behaviour,
        RelationshipBehaviour.redirect,
      );
      expect(
        choose(guarded, r, TopicAccess.sensitive).behaviour,
        RelationshipBehaviour.deflect,
      );
    });

    test('every behaviour that closes a conversation offers a doorway', () {
      for (final stage in RelationshipStage.values) {
        for (final access in TopicAccess.values) {
          for (final defensive in VoiceLevel.values) {
            for (var seed = 1; seed <= 3; seed++) {
              final c = choose(
                voice(defensiveness: defensive),
                at(stage),
                access,
                seed: seed,
              );
              if (c.behaviour.closes) {
                expect(
                  c.doorway,
                  isNotNull,
                  reason:
                      '${c.behaviour.name} at ${stage.name} on ${access.name}',
                );
              }
            }
          }
        }
      }
    });

    test('is never closed once the relationship has earned it', () {
      for (var seed = 1; seed <= 40; seed++) {
        final c = choose(
          voice(),
          at(RelationshipStage.trusted),
          TopicAccess.deep,
          seed: seed,
        );
        expect(
          c.behaviour.closes &&
              c.doorway != null &&
              c.behaviour != RelationshipBehaviour.deflect &&
              c.behaviour != RelationshipBehaviour.redirect,
          isFalse,
        );
      }
      final open = choose(
        voice(defensiveness: VoiceLevel.veryLow),
        at(RelationshipStage.connected),
        TopicAccess.protectedTopic,
      );
      expect(open.behaviour.closes, isFalse);
      expect(open.doorway, isNull);
    });

    test('the author can insist, and the character answers reluctantly', () {
      for (var seed = 1; seed <= 20; seed++) {
        final c = choose(
          voice(),
          at(RelationshipStage.newStage),
          TopicAccess.deep,
          seed: seed,
          insists: true,
        );
        expect(c.reluctant, isTrue);
        expect(
          c.behaviour.closes,
          isFalse,
          reason: 'insisting opens the topic, with reluctance',
        );
      }
    });

    test('is not reluctant about a topic it was willing to discuss anyway', () {
      final c = choose(
        voice(),
        at(RelationshipStage.newStage),
        TopicAccess.surface,
        insists: true,
      );
      expect(c.reluctant, isFalse);
    });
  });

  group(
    'when the author proposes something the character does not recognise',
    () {
      test('a pushy, established character challenges', () {
        final c = choose(
          voice(challenge: VoiceLevel.veryHigh),
          at(RelationshipStage.trusted, willing: 0.8),
          TopicAccess.personal,
          disagreement: disagreement(),
        );
        expect(c.behaviour, RelationshipBehaviour.challenge);
        expect(c.reasons.join(' '), contains('never abandons'));
      });

      test('quotes what it is pointing to', () {
        final c = choose(
          voice(challenge: VoiceLevel.high),
          at(RelationshipStage.familiar),
          TopicAccess.personal,
          disagreement: disagreement(),
        );
        expect(c.reasons.join(' '), contains('Kali never abandons anyone'));
      });

      test('corrects when the conflict is with something firmly recorded', () {
        final c = choose(
          voice(challenge: VoiceLevel.medium),
          at(RelationshipStage.connected, willing: 1.0),
          TopicAccess.personal,
          disagreement: disagreement(strength: 0.9),
        );
        expect({
          RelationshipBehaviour.challenge,
          RelationshipBehaviour.correct,
        }, contains(c.behaviour));
      });

      test(
        'an easygoing character with no appetite for it lets a mild one stand',
        () {
          final c = choose(
            voice(challenge: VoiceLevel.veryLow),
            at(RelationshipStage.newStage, willing: 0.0),
            TopicAccess.personal,
            disagreement: disagreement(strength: 0.3),
          );
          expect(c.behaviour, RelationshipBehaviour.trust);
        },
      );

      test('a new relationship still lets the character disagree', () {
        final c = choose(
          voice(challenge: VoiceLevel.veryHigh),
          at(RelationshipStage.newStage, willing: 0.9),
          TopicAccess.personal,
          disagreement: disagreement(),
        );
        expect({
          RelationshipBehaviour.challenge,
          RelationshipBehaviour.correct,
        }, contains(c.behaviour));
      });

      test(
        'a closed topic is closed even when the author has proposed something',
        () {
          final c = choose(
            voice(),
            at(RelationshipStage.newStage),
            TopicAccess.protectedTopic,
            disagreement: disagreement(),
          );
          expect(c.behaviour.closes, isTrue);
        },
      );
    },
  );

  group('what the relationship makes possible', () {
    test('a stranger does not tease or open up', () {
      for (var seed = 1; seed <= 60; seed++) {
        final c = choose(
          voice(humour: VoiceLevel.veryHigh, openness: VoiceLevel.veryHigh),
          at(RelationshipStage.newStage),
          TopicAccess.personal,
          seed: seed,
          turn: seed,
        );
        expect(c.behaviour, isNot(RelationshipBehaviour.tease));
        expect(c.behaviour, isNot(RelationshipBehaviour.vulnerability));
      }
    });

    test('a funny character who knows the author teases', () {
      final run = simulate(
        voice(humour: VoiceLevel.veryHigh),
        at(RelationshipStage.connected),
        TopicAccess.personal,
        seed: 5,
      );
      expect(run, contains(RelationshipBehaviour.tease));
    });

    test('a stolid one who knows the author just as well teases less', () {
      int teases(VoiceLevel humour) => simulate(
        voice(humour: humour),
        at(RelationshipStage.connected),
        TopicAccess.personal,
        seed: 5,
      ).where((b) => b == RelationshipBehaviour.tease).length;
      expect(teases(VoiceLevel.veryLow), lessThan(teases(VoiceLevel.veryHigh)));
    });
    test(
      'an open, trusted character shows vulnerability about something tender',
      () {
        final c = choose(
          voice(openness: VoiceLevel.veryHigh, humour: VoiceLevel.veryLow),
          at(RelationshipStage.connected, willing: 0.0),
          TopicAccess.sensitive,
        );
        expect(c.behaviour, RelationshipBehaviour.vulnerability);
      },
    );

    test('and not about something light', () {
      for (var turn = 0; turn < 30; turn++) {
        final c = choose(
          voice(openness: VoiceLevel.veryHigh),
          at(RelationshipStage.connected),
          TopicAccess.surface,
          turn: turn,
          seed: 3,
        );
        expect(c.behaviour, isNot(RelationshipBehaviour.vulnerability));
      }
    });

    test('a reserved character does not open up even when trusted', () {
      final seen = <RelationshipBehaviour>{
        for (var turn = 0; turn < 30; turn++)
          choose(
            voice(openness: VoiceLevel.veryLow),
            at(RelationshipStage.trusted),
            TopicAccess.sensitive,
            turn: turn,
            seed: 3,
          ).behaviour,
      };
      expect(seen, isNot(contains(RelationshipBehaviour.vulnerability)));
    });
  });

  group('the passing mood', () {
    test('a guarded character is less open than a calm one', () {
      var calm = 0;
      var guarded = 0;
      for (var seed = 1; seed <= 60; seed++) {
        final r = at(RelationshipStage.trusted);
        final v = voice(openness: VoiceLevel.high);
        if (choose(v, r, TopicAccess.sensitive, seed: seed).behaviour ==
            RelationshipBehaviour.vulnerability) {
          calm++;
        }
        if (choose(
              v,
              r,
              TopicAccess.sensitive,
              seed: seed,
              mood: EmotionalState.guarded,
            ).behaviour ==
            RelationshipBehaviour.vulnerability) {
          guarded++;
        }
      }
      expect(guarded, lessThanOrEqualTo(calm));
    });

    test('a playful character jokes more than a calm one', () {
      final v = voice(humour: VoiceLevel.high);
      final r = at(RelationshipStage.familiar);
      int light(EmotionalState mood) =>
          simulate(v, r, TopicAccess.personal, seed: 9, mood: mood)
              .where(
                (b) =>
                    b == RelationshipBehaviour.tease ||
                    b == RelationshipBehaviour.humour,
              )
              .length;
      expect(
        light(EmotionalState.playful),
        greaterThan(light(EmotionalState.calm)),
      );
    });
    test('is not part of the voice or the relationship', () {
      final v = voice();
      final r = at(RelationshipStage.familiar);
      choose(v, r, TopicAccess.personal, mood: EmotionalState.irritated);
      expect(v.toJson(), voice().toJson());
      expect(r.toJson(), at(RelationshipStage.familiar).toJson());
    });
  });

  group('variety', () {
    BehaviourHistory run(List<RelationshipBehaviour> behaviours) =>
        BehaviourHistory(behaviours);

    test('a behaviour just used is less likely again', () {
      const t = RelationshipBehaviour.trust;
      final v = voice(humour: VoiceLevel.high);
      final r = at(RelationshipStage.familiar);
      final used = choose(
        v,
        r,
        TopicAccess.personal,
        turn: 3,
        seed: 2,
        history: run([t, t]),
      );
      expect(used.reasons, isNotEmpty);
    });

    test('three plain answers in a row are never followed by a fourth', () {
      const t = RelationshipBehaviour.trust;
      for (final stage in RelationshipStage.values) {
        for (var seed = 1; seed <= 20; seed++) {
          final c = choose(
            voice(),
            at(stage),
            TopicAccess.personal,
            seed: seed,
            history: run([t, t, t]),
          );
          expect(c.behaviour, isNot(t), reason: stage.name);
        }
      }
    });

    test('three pushes in a row are never followed by a fourth', () {
      const pushes = [
        RelationshipBehaviour.challenge,
        RelationshipBehaviour.correct,
        RelationshipBehaviour.challenge,
      ];
      for (var seed = 1; seed <= 20; seed++) {
        final c = choose(
          voice(challenge: VoiceLevel.veryHigh),
          at(RelationshipStage.connected, willing: 1.0),
          TopicAccess.personal,
          seed: seed,
          history: run(pushes),
          disagreement: disagreement(strength: 0.9),
        );
        expect(c.behaviour.pushes, isFalse);
      }
    });

    test(
      'a long run of disagreements is not met with constant confrontation',
      () {
        var history = const BehaviourHistory();
        var longest = 0;
        var current = 0;
        final v = voice(challenge: VoiceLevel.veryHigh);
        final r = at(RelationshipStage.connected, willing: 1.0);
        for (var turn = 0; turn < 80; turn++) {
          final c = choose(
            v,
            r,
            TopicAccess.personal,
            turn: turn,
            seed: 4,
            history: history,
            disagreement: disagreement(strength: 0.8),
          );
          history = history.add(c.behaviour);
          current = c.behaviour.pushes ? current + 1 : 0;
          if (current > longest) longest = current;
        }
        expect(longest, lessThanOrEqualTo(3));
      },
    );

    test('a long conversation does not become constant agreement', () {
      final run = simulate(
        voice(),
        at(RelationshipStage.familiar),
        TopicAccess.personal,
        turns: 120,
        seed: 6,
      );
      var longest = 0;
      var current = 0;
      for (final b in run) {
        current = b == RelationshipBehaviour.trust ? current + 1 : 0;
        if (current > longest) longest = current;
      }
      expect(longest, lessThanOrEqualTo(3));
      expect(run.toSet().length, greaterThanOrEqualTo(2));
    });

    test('a rich character shows a range over a long conversation', () {
      final v = voice(
        humour: VoiceLevel.high,
        openness: VoiceLevel.high,
        challenge: VoiceLevel.high,
        defensiveness: VoiceLevel.high,
      );
      final r = at(RelationshipStage.connected, willing: 0.8);
      final seen = <RelationshipBehaviour>{};
      for (final access in [
        TopicAccess.personal,
        TopicAccess.sensitive,
        TopicAccess.deep,
      ]) {
        seen.addAll(simulate(v, r, access, turns: 60, seed: 11));
      }
      expect(seen.length, greaterThanOrEqualTo(4), reason: '$seen');
    });
    test('keeps only the recent past', () {
      var h = const BehaviourHistory();
      for (var i = 0; i < 50; i++) {
        h = h.add(RelationshipBehaviour.trust);
      }
      expect(h.recent.length, 12);
      expect(h.last(3).length, 3);
    });
  });

  group('replaying', () {
    test('the same turn chooses the same behaviour', () {
      final v = voice(humour: VoiceLevel.high);
      final r = at(RelationshipStage.familiar);
      for (var turn = 0; turn < 10; turn++) {
        expect(
          choose(v, r, TopicAccess.personal, turn: turn, seed: 8).behaviour,
          choose(v, r, TopicAccess.personal, turn: turn, seed: 8).behaviour,
        );
      }
    });
  });
}
