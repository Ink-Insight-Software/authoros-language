/// What the words mean: feelings, how strong, denied or not, and what is held
/// together.
library;

import 'package:authoros_language/authoros_language.dart';
import 'package:test/test.dart';

EmotionHit only(String text) {
  final hits = Lexicon.emotions(text);
  expect(hits, hasLength(1), reason: text);
  return hits.single;
}

void main() {
  group('feelings', () {
    test('a word is placed in its family, at its strength', () {
      expect(only('She was nervous').family, EmotionFamily.fear);
      expect(only('She was nervous').intensity, Intensity.low);
      expect(only('She was afraid').intensity, Intensity.mid);
      expect(only('She was terrified').intensity, Intensity.high);
      expect(only('He is furious').family, EmotionFamily.anger);
      expect(only('heartbroken').family, EmotionFamily.grief);
      expect(only('She felt ashamed').family, EmotionFamily.shame);
    });

    test('forms of a word are the word: fears, feared, fearing', () {
      for (final w in ['fears', 'feared', 'fearing']) {
        expect(only('she $w it').family, EmotionFamily.fear, reason: w);
      }
    });

    test('"brave" is courage, which the old word list missed', () {
      expect(only('You felt brave').family, EmotionFamily.courage);
    });

    test('every feeling in a sentence, in order, as the author wrote it', () {
      final hits = Lexicon.emotions('You felt fear, and brave.');
      expect([for (final h in hits) h.word], ['fear', 'brave']);
      expect(
        [for (final h in hits) h.family],
        [EmotionFamily.fear, EmotionFamily.courage],
      );
    });

    test('ordinary words that merely look like feelings are not feelings', () {
      for (final t in [
        'He opened the door and sat down',
        'It was a kind of lamp, easy to carry',
        'She lost the key and was lost in the market',
        'They were safe, calm, and content',
        'The room was low and blue',
      ]) {
        expect(Lexicon.emotions(t), isEmpty, reason: t);
      }
    });
  });

  group('denial and degree', () {
    test('"not afraid" names a feeling and denies it', () {
      for (final t in [
        'She was not afraid',
        "She wasn't afraid",
        'She was never really afraid',
        'There was no fear in her',
        'She was not at all afraid',
      ]) {
        expect(only(t).negated, isTrue, reason: t);
      }
    });

    test('a denial stops at a comma and at "but"', () {
      final a = Lexicon.emotions('No, she was afraid');
      expect(a.single.negated, isFalse);
      final b = Lexicon.emotions('She was not afraid but brave');
      expect([for (final h in b) h.negated], [true, false]);
    });

    test(
      '"very" raises, "a little" lowers, and neither goes past the ends',
      () {
        expect(only('very afraid').intensity, Intensity.high);
        expect(only('a little afraid').intensity, Intensity.low);
        expect(only('terribly terrified').intensity, Intensity.high);
        expect(only('slightly nervous').intensity, Intensity.low);
      },
    );

    test('only what was felt counts as felt', () {
      expect(Lexicon.feltWords('not afraid, just angry'), {'angry'});
    });
  });

  group('two things at once', () {
    test('a feeling and its opposite are a contrast', () {
      final c = Lexicon.contrast(Lexicon.emotions('afraid, and brave'))!;
      expect(c.$1.family, EmotionFamily.fear);
      expect(c.$2.family, EmotionFamily.courage);
      expect(
        Lexicon.contrast(Lexicon.emotions('proud and ashamed')),
        isNotNull,
      );
    });

    test('feelings that do not oppose are not a contrast', () {
      expect(Lexicon.contrast(Lexicon.emotions('afraid and angry')), isNull);
    });

    test('a denied feeling is not one half of a contrast', () {
      expect(
        Lexicon.contrast(Lexicon.emotions('not afraid, and brave')),
        isNull,
      );
    });
  });

  group('kin and kinds', () {
    test('relatives, places and events are told apart, once each', () {
      final hits = Lexicon.kinds(
        'Her mother died after the wreck, out on the water, the water again',
      );
      expect(
        [for (final h in hits) '${h.kind}:${h.word}'],
        ['kin:mother', 'event:wreck', 'place:water'],
      );
    });
  });

  group('in the reader', () {
    const reader = RuleBasedResponseReader();

    test('a feeling that is denied is not read as felt', () {
      final a = reader.read('She was not afraid, only tired');
      expect(a.terms.emotions, isEmpty);
    });

    test('a word the old list did not have is heard', () {
      expect(reader.read('You felt fear, and brave.').terms.emotions, {
        'fear',
        'brave',
      });
    });

    test('the old words are still heard', () {
      expect(reader.read('She was terrified and grieving').terms.emotions, {
        'terrified',
        'grieving',
      });
    });
  });
}
