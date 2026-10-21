/// A character's voice: how they speak, never what they know.
///
/// Phase 3.1 and 3.2 of the master build plan ask for a voice profile that is
/// project-scoped, has safe defaults when a character has none, can be edited, and
/// *cannot override explicit canon*. The last is held structurally: the stored
/// fields are a fixed list of ways of speaking, and a test fails if one is added
/// that looks like a fact.
library;

import 'package:authoros_language/authoros_language.dart';
import 'package:test/test.dart';

VoiceProfile profile() => const VoiceProfile(
  projectId: 'northstar',
  characterId: 'kali',
  tone: VoiceTone.dry,
  energy: VoiceLevel.low,
  humour: VoiceLevel.high,
  openness: VoiceLevel.veryLow,
  confidence: VoiceLevel.veryHigh,
  communicationLength: CommunicationLength.terse,
  defensiveness: VoiceLevel.high,
  affection: VoiceLevel.low,
  challengeLevel: VoiceLevel.high,
  vocabulary: VocabularyRegister.earthy,
  rhythm: ConversationalRhythm.clipped,
  speechPatterns: ['Right.', 'If you say so.'],
  voiceNotes: 'Never explains herself twice.',
  examples: ['Not tonight.'],
);

void main() {
  group('the neutral voice', () {
    test('is the middle of every scale, for a character with none', () {
      const voice = VoiceProfile.defaults(projectId: 'p', characterId: 'c');
      expect(voice.isDefault, isTrue);
      expect(voice.tone, VoiceTone.neutral);
      for (final level in [
        voice.energy,
        voice.humour,
        voice.openness,
        voice.confidence,
        voice.defensiveness,
        voice.affection,
        voice.challengeLevel,
      ]) {
        expect(level, VoiceLevel.medium);
      }
      expect(voice.communicationLength, CommunicationLength.measured);
    });

    test('stops being the default as soon as anything is set', () {
      const base = VoiceProfile.defaults(projectId: 'p', characterId: 'c');
      expect(base.copyWith(humour: VoiceLevel.high).isDefault, isFalse);
      expect(base.copyWith(speechPatterns: ['Right.']).isDefault, isFalse);
      expect(base.copyWith(voiceNotes: 'Quiet.').isDefault, isFalse);
      expect(base.copyWith(examples: ['Hm.']).isDefault, isFalse);
    });

    test('belongs to one project and one character', () {
      final voice = profile().copyWith(tone: VoiceTone.warm);
      expect(voice.projectId, 'northstar');
      expect(voice.characterId, 'kali');
    });
  });

  group('the scale', () {
    test('runs from zero to one in five steps', () {
      expect(
        [for (final l in VoiceLevel.values) l.value],
        [0.0, 0.25, 0.5, 0.75, 1.0],
      );
    });

    test('maps a number back to the nearest step and clamps', () {
      expect(VoiceLevel.fromValue(0.5), VoiceLevel.medium);
      expect(VoiceLevel.fromValue(0.9), VoiceLevel.veryHigh);
      expect(VoiceLevel.fromValue(-4), VoiceLevel.veryLow);
      expect(VoiceLevel.fromValue(7), VoiceLevel.veryHigh);
      for (final level in VoiceLevel.values) {
        expect(VoiceLevel.fromValue(level.value), level);
      }
    });
  });

  group('storing a voice', () {
    test('survives a round trip, so it persists after a restart', () {
      final original = profile();
      final back = VoiceProfile.fromJson(original.toJson())!;
      expect(back.toJson(), original.toJson());
      expect(back.speechPatterns, ['Right.', 'If you say so.']);
      expect(back.voiceNotes, 'Never explains herself twice.');
    });

    test('reads a missing field as that field\'s default', () {
      final back = VoiceProfile.fromJson({
        'projectId': 'p',
        'characterId': 'c',
        'tone': 'warm',
      })!;
      expect(back.tone, VoiceTone.warm);
      expect(back.humour, VoiceLevel.medium);
      expect(back.speechPatterns, isEmpty);
    });

    test('reads a value this version does not know as the default', () {
      final back = VoiceProfile.fromJson({
        'projectId': 'p',
        'characterId': 'c',
        'tone': 'a tone added next year',
        'humour': 'very, very high',
        'rhythm': 3,
      })!;
      expect(back.tone, VoiceTone.neutral);
      expect(back.humour, VoiceLevel.medium);
      expect(back.rhythm, ConversationalRhythm.even);
    });

    test('keeps what it understands from a newer version\'s profile', () {
      final stored = {
        ...profile().toJson(),
        'schemaVersion': 99,
        'a field from the future': {'anything': true},
      };
      final back = VoiceProfile.fromJson(stored)!;
      expect(back.tone, VoiceTone.dry);
      expect(back.challengeLevel, VoiceLevel.high);
    });

    test('drops list entries that are not text', () {
      final back = VoiceProfile.fromJson({
        'projectId': 'p',
        'characterId': 'c',
        'speechPatterns': ['Right.', 4, null, 'Fine.'],
      })!;
      expect(back.speechPatterns, ['Right.', 'Fine.']);
    });

    test('is nothing without a project and a character', () {
      expect(VoiceProfile.fromJson(null), isNull);
      expect(VoiceProfile.fromJson('voice'), isNull);
      expect(VoiceProfile.fromJson({'characterId': 'c'}), isNull);
      expect(VoiceProfile.fromJson({'projectId': 'p'}), isNull);
    });
  });

  group('a voice holds style and never fact', () {
    test('stores exactly the fields it lists', () {
      expect(profile().toJson().keys.toList(), VoiceProfile.storedFields);
    });

    test('has no field that could hold something the character knows', () {
      const factLike = [
        'backstory',
        'history',
        'secret',
        'goal',
        'fear',
        'belief',
        'value',
        'age',
        'occupation',
        'relationship',
        'canon',
        'fact',
        'knows',
        'memory',
      ];
      for (final field in VoiceProfile.storedFields) {
        for (final word in factLike) {
          expect(
            field.toLowerCase(),
            isNot(contains(word)),
            reason:
                '"$field" looks like a fact. A voice is how a character '
                'speaks, and what they know stays in the project\'s records.',
          );
        }
      }
    });
  });
}
