/// A character showing it heard: about the answer, in its own words, in its tone.
library;

import 'package:authoros_core/procedural/generation_seed.dart';
import 'package:authoros_language/authoros_language.dart';
import 'package:test/test.dart';

const reader = RuleBasedResponseReader();
const ctx = ReaderContext(
  people: {'Tom Hale', 'Edda Voss'},
  places: {'Dock Nine'},
  events: {'The Wreck'},
);

Heard hear(String text) => Heard.from(reader.read(text, context: ctx));

Acknowledgement ack(
  String text, {
  ListenTone tone = ListenTone.neutral,
  int turn = 4,
  int seed = 1,
  List<String> recent = const [],
  ListenCues cues = const ListenCues(),
  bool terse = false,
}) => Listening.acknowledge(
  hear(text),
  tone: tone,
  seed: GenerationSeed.root(seed),
  turn: turn,
  recent: recent,
  cues: cues,
  terse: terse,
);

void main() {
  group('acknowledging', () {
    test('the screenshot: "You felt fear, and brave." is heard as both', () {
      final a = ack('You felt fear, and brave.');
      expect(a.lines.first, 'Fear and brave, at once.');
      expect(a.lines.length, 2);
    });

    test('a strong feeling is said back in the author\'s own word', () {
      expect(
        ack('She was terrified of the water').lines.first,
        startsWith('Terrified.'),
      );
    });

    test('degree is heard: "a little afraid" is not "terrified"', () {
      expect(
        ack('She was a little afraid').lines.first,
        startsWith('Afraid, '),
      );
      expect(ack('She was a little afraid').lines.first, contains('little'));
    });

    test('a denied feeling is said back as denied', () {
      expect(
        ack('She was not afraid, only tired').lines.first,
        startsWith('Not afraid.'),
      );
    });

    test('two feelings that do not oppose are named together', () {
      expect(ack('She was afraid and angry').lines.first, 'Afraid and angry.');
    });

    test('a person, an event and a place are each picked up by name', () {
      expect(ack('It was Tom Hale who told her').lines.first, contains('Tom'));
      expect(
        ack('Everything changed after The Wreck').lines.first,
        contains('The Wreck'),
      );
      expect(
        ack('She goes back to Dock Nine most nights').lines.first,
        contains('Dock Nine'),
      );
    });

    test('what is wanted, feared and valued is said back', () {
      expect(
        ack('She wants to leave the harbour for good').lines.first,
        'Wanting to leave the harbour for good.',
      );
      expect(
        ack('She dreads the dark water').lines.first,
        startsWith('Dreads'),
      );
    });

    test('with nothing recognised, the last of what was said comes back', () {
      expect(
        ack('Mostly the harbour, and the long nights').lines.first,
        startsWith('The long nights.'),
      );
    });

    test('a passing "I don\'t know" is met, not quoted', () {
      expect(
        ack("I don't know").lines.first,
        matches(RegExp('another', caseSensitive: false)),
      );
    });

    test('a pass or a stop is not acknowledged as an answer', () {
      expect(ack('skip').lines, isEmpty);
    });

    test('a correction and a disagreement are known for what they are', () {
      expect(ack('Actually no, that is wrong').lines.first, contains('wrong'));
    });
  });

  group('in the character\'s tone', () {
    test('the same strong feeling is put each tone\'s own way', () {
      final said = {
        for (final t in ListenTone.values)
          ack('She was terrified', tone: t).lines.first,
      };
      // Every manner with a bank of its own sounds like itself; three older
      // buckets remain, and none of them is lost.
      expect(said.length, greaterThanOrEqualTo(ListenTone.values.length - 1));
      for (final s in said) {
        expect(s, startsWith('Terrified'));
      }
    });

    test('a terse character says the least: one line', () {
      expect(ack('You felt fear, and brave.', terse: true).lines, hasLength(1));
    });
  });

  group('from the project, as what the author wrote', () {
    test('a person is placed by how the project connects them', () {
      const cues = ListenCues(links: {'Tom Hale': 'confirmed'});
      final a = ack('It was Tom Hale who told her', cues: cues);
      expect(a.lines.last, "You've put Tom close to me.");
    });

    test('a link nobody wrote is said to be unwritten, never invented', () {
      const cues = ListenCues(links: {'Tom Hale': 'unknown'});
      expect(
        ack('It was Tom Hale', cues: cues).lines.last,
        "You haven't said what Tom and I are to each other.",
      );
    });

    test('a person with no link is just named', () {
      expect(ack('It was Tom Hale').lines, hasLength(1));
    });

    test('what the author wrote about a place is quoted, as written', () {
      const cues = ListenCues(
        placeNotes: {'Dock Nine': 'The ferry ties up here'},
      );
      final a = ack('She goes back to Dock Nine', cues: cues);
      expect(a.lines.last, 'You wrote that it is "The ferry ties up here".');
    });

    test('the same remark about a person is not made twice running', () {
      const cues = ListenCues(links: {'Tom Hale': 'confirmed'});
      final first = ack('It was Tom Hale', cues: cues);
      final again = ack('It was Tom Hale', cues: cues, recent: first.fragments);
      expect(again.lines.where((l) => l.contains('close to me')), isEmpty);
    });
  });

  group('reflecting', () {
    GenerationSeed seed() => GenerationSeed.root(3);

    test('a kind of feeling gets a remark about that kind', () {
      final r = Listening.reflection(
        hear('She was terrified'),
        seed: seed(),
        turn: 4,
      );
      expect(r, anyOf(contains('Fear'), contains('fear')));
    });

    test('feelings held together are met with a remark about holding both', () {
      final r = Listening.reflection(
        hear('afraid, and brave'),
        seed: seed(),
        turn: 4,
      );
      expect(
        r,
        anyOf('Both can be true.', 'Holding both is harder than choosing.'),
      );
    });

    test('no feeling, no remark', () {
      expect(
        Listening.reflection(hear('Mostly the harbour'), seed: seed(), turn: 4),
        isNull,
      );
    });

    test('a remark made lately is not made again', () {
      final used = <String>[];
      final first = Listening.reflection(
        hear('She was terrified'),
        seed: seed(),
        turn: 4,
        used: used,
      );
      final second = Listening.reflection(
        hear('She was terrified'),
        seed: seed(),
        turn: 5,
        recent: used,
      );
      expect(second, isNot(first));
    });
  });

  group('recalling', () {
    GenerationSeed seed() => GenerationSeed.root(5);

    String? callback(String now, List<String> before, {int turn = 6}) {
      for (var t = turn; t < turn + 40; t++) {
        final c = Listening.callback(
          hear(now),
          [for (final b in before) hear(b)],
          seed: seed(),
          turn: t,
        );
        if (c != null) return c;
      }
      return null;
    }

    test('something said before is noticed, with the right count', () {
      expect(
        callback('She was terrified again', ['She was afraid of it']),
        'Terrified again. You said that earlier too.',
      );
      expect(
        callback('Afraid, always afraid', [
          'She was afraid of it',
          'Terrified, really',
        ]),
        "That's the third time afraid has come up.",
      );
    });

    test('a name that comes back is noticed too', () {
      expect(
        callback('It was Tom Hale again', ['Tom Hale knew']),
        'Tom again. You said that earlier too.',
      );
    });

    test('nothing repeated, nothing said', () {
      expect(callback('She was angry', ['It was Tom Hale']), isNull);
    });

    test('not twice in a row', () {
      final c = Listening.callback(
        hear('afraid again'),
        [hear('afraid before')],
        seed: seed(),
        turn: 6,
        recent: const ['callback.feeling:fear.2'],
      );
      expect(c, isNull);
    });
  });

  test('every stock line is in the audit, and none states a fact', () {
    final phrases = Listening.phrases;
    expect(phrases, isNotEmpty);
    for (final p in phrases) {
      // Slots stand for the author's words or the project's; the rest is stock.
      expect(p, isNot(contains('canon')));
      expect(p.trim(), isNotEmpty);
    }
  });
}
