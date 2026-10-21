/// The character voice layer: each tone sounds like itself.
library;

import 'package:authoros_core/procedural/generation_seed.dart';
import 'package:authoros_language/authoros_language.dart';
import 'package:test/test.dart';

import 'language_layer_test.dart' as base;

const asking = [
  RelationshipBehaviour.trust,
  RelationshipBehaviour.tease,
  RelationshipBehaviour.challenge,
  RelationshipBehaviour.correct,
  RelationshipBehaviour.vulnerability,
  RelationshipBehaviour.humour,
];
const closing = [
  RelationshipBehaviour.deflect,
  RelationshipBehaviour.redirect,
  RelationshipBehaviour.withhold,
  RelationshipBehaviour.refuse,
];

double avgWords(Iterable<String> lines) =>
    lines.map((l) => l.split(RegExp(r'\s+')).length).reduce((a, b) => a + b) /
    lines.length;

void main() {
  group('every manner has a full bank', () {
    for (final t in MannerBanks.manners) {
      test(t.name, () {
        final d = MannerBanks.delivery(t)!;
        final l = MannerBanks.listening(t)!;
        for (final b in asking) {
          expect(d.leads[b], hasLength(3), reason: 'lead $b');
        }
        for (final b in closing) {
          expect(d.closings[b], hasLength(3), reason: 'closing $b');
        }
        expect(d.reactions, hasLength(3));
        expect(d.greetings, hasLength(2));
        expect(d.welcomes, hasLength(2));
        expect(d.stranger, hasLength(2));
        expect(d.reluctant, hasLength(3));
        expect(d.sceneOpen, contains('{scene}'));
        for (final pool in [l.feltHigh, l.feltMid, l.feltLow]) {
          expect(pool.length, greaterThanOrEqualTo(2));
          for (final s in pool) {
            expect(s, contains('{W}'));
          }
        }
        for (final s in l.denied) {
          expect(s, contains('{W}'));
        }
        for (final s in l.person) {
          expect(s, contains('{N}'));
        }
        for (final s in l.event) {
          expect(s, contains('{E}'));
        }
        for (final s in l.place) {
          expect(s, contains('{P}'));
        }
        for (final s in [...l.kind, ...l.kin]) {
          expect(s, contains('{K}'));
        }
        for (final pool in [
          l.several,
          l.contrast,
          l.correction,
          l.disagreement,
          l.possibilities,
          l.unsure,
          l.echoTag,
        ]) {
          expect(pool, isNotEmpty);
          for (final s in pool) {
            expect(s, isNot(contains('{')));
          }
        }
        for (final pool in [
          ...d.leads.values,
          ...d.closings.values,
          d.reactions,
          d.greetings,
          d.welcomes,
          d.stranger,
          d.reluctant,
          l.feltHigh,
          l.feltMid,
          l.feltLow,
          l.several,
          l.contrast,
          l.denied,
          l.person,
          l.event,
          l.place,
          l.kind,
          l.kin,
          l.echoTag,
        ]) {
          expect(pool.toSet(), hasLength(pool.length), reason: '$pool');
        }
      });
    }

    test('a manner is mostly its own lines, not another one\'s', () {
      for (final t in MannerBanks.manners) {
        final mine = [
          ...MannerBanks.delivery(t)!.all,
          ...MannerBanks.listening(t)!.all,
        ];
        final others = {
          for (final o in MannerBanks.manners.where((o) => o != t)) ...[
            ...MannerBanks.delivery(o)!.all,
            ...MannerBanks.listening(o)!.all,
          ],
        };
        final own = mine.where((l) => !others.contains(l)).length;
        expect(own / mine.length, greaterThan(0.85), reason: t.name);
      }
    });
  });

  group('each sounds like itself', () {
    List<String> said(ListenTone t) {
      final d = MannerBanks.delivery(t)!;
      return [
        ...d.leads.values.expand((p) => p),
        ...d.closings.values.expand((p) => p),
        ...d.reactions,
      ];
    }

    test('timid hedges, apologises and trails off', () {
      final marked = said(ListenTone.timid).where(
        (l) =>
            RegExp(r'sorry|um\b|\.\.\.|oh', caseSensitive: false).hasMatch(l),
      );
      expect(marked.length / said(ListenTone.timid).length, greaterThan(0.8));
    });

    test('quiet says very little', () {
      expect(avgWords(said(ListenTone.quiet)), lessThan(3.5));
      expect(
        avgWords(said(ListenTone.quiet)),
        lessThan(avgWords(said(ListenTone.formal))),
      );
    });

    test('blunt does not soften', () {
      expect(avgWords(said(ListenTone.blunt)), lessThan(5.5));
      for (final l in said(ListenTone.blunt)) {
        expect(l.toLowerCase(), isNot(contains('sorry')));
        expect(l.toLowerCase(), isNot(contains('please')));
      }
    });

    test('formal uses no contractions', () {
      final all = [
        ...MannerBanks.delivery(ListenTone.formal)!.all,
        ...MannerBanks.listening(ListenTone.formal)!.all,
      ];
      for (final l in all) {
        expect(
          l,
          isNot(matches(RegExp(r"\w'(s|t|re|ve|ll|d|m)\b"))),
          reason: l,
        );
      }
    });

    test('playful is light, with exclamations and laughter', () {
      final all = [
        ...MannerBanks.delivery(ListenTone.playful)!.all,
        ...MannerBanks.listening(ListenTone.playful)!.all,
      ];
      final marked = all.where(
        (l) => RegExp(r'!|\bha\b|ooh|huh', caseSensitive: false).hasMatch(l),
      );
      expect(marked.length / all.length, greaterThan(0.5));
    });

    test('sardonic is sarcastic and stoic is level', () {
      final sar = said(ListenTone.sardonic).join(' ').toLowerCase();
      expect(
        sar,
        anyOf(contains('naturally'), contains('riveting'), contains('oh,')),
      );
      final sto = said(ListenTone.stoic).join(' ');
      expect(sto, isNot(contains('!')));
      expect(sto, isNot(contains('...')));
    });
  });

  group('in delivery', () {
    test('the same request is put differently by every tone', () {
      final texts = {
        for (final t in VoiceTone.values)
          t: base.delivery.deliver(base.request(base.voice(t))).text,
      };
      // Warm, gentle and earnest share a bank; every other tone is its own.
      expect(texts.values.toSet().length, greaterThanOrEqualTo(9));
    });

    test('the question is never rewritten in any tone', () {
      for (final t in VoiceTone.values) {
        for (final b in asking) {
          for (var seed = 0; seed < 6; seed++) {
            final d = base.delivery.deliver(
              base.request(base.voice(t), behaviour: b, seed: seed),
            );
            expect(d.question, base.question, reason: '$t $b');
            expect(d.text, contains(base.question));
          }
        }
      }
    });

    test(
      'everything but the question and the author\'s words is in the bank',
      () {
        for (final t in VoiceTone.values) {
          for (var seed = 0; seed < 8; seed++) {
            for (final b in [...asking, ...closing]) {
              final d = base.delivery.deliver(
                base.request(
                  base.voice(t),
                  behaviour: b,
                  seed: seed,
                  q: closing.contains(b) ? null : base.question,
                ),
              );
              for (final line in d.lines) {
                if (line.kind == LineKind.question) {
                  final rest = line.text.replaceAll(base.question, '').trim();
                  var lead = rest;
                  for (final h in unsureHedges) {
                    if (lead.startsWith(h)) {
                      lead = lead.substring(h.length).trim();
                    }
                  }
                  if (lead.isNotEmpty) {
                    expect(
                      RuleBasedDelivery.phrases.contains(lead),
                      isTrue,
                      reason: '$t $b "$lead"',
                    );
                  }
                } else {
                  expect(
                    RuleBasedDelivery.isBank(line.text),
                    isTrue,
                    reason: '$t $b "${line.text}"',
                  );
                }
              }
            }
          }
        }
      },
    );

    test('a quiet character acknowledges but does not stop to remark', () {
      for (var seed = 0; seed < 25; seed++) {
        final r = base.request(
          base.voice(VoiceTone.quiet),
          seed: seed,
          last: 'I was terrified and I could not tell anyone',
        );
        final d = base.delivery.deliver(
          DeliveryRequest(
            style: r.style,
            voice: r.voice,
            stage: r.stage,
            seed: r.seed,
            turn: r.turn,
            question: r.question,
            lastAuthorText: r.lastAuthorText,
            heard: Heard.from(
              const RuleBasedResponseReader().read(r.lastAuthorText!),
            ),
          ),
        );
        expect(d.lines.where((l) => l.kind == LineKind.reflection), isEmpty);
      }
    });

    test('a character with low confidence sometimes hedges, in bank words', () {
      var hedged = 0;
      for (var seed = 0; seed < 60; seed++) {
        final v = base
            .voice(VoiceTone.dry)
            .copyWith(confidence: VoiceLevel.veryLow);
        final d = base.delivery.deliver(base.request(v, seed: seed));
        final q = d.lines.firstWhere((l) => l.kind == LineKind.question).text;
        if (unsureHedges.any(q.contains)) hedged++;
      }
      expect(hedged, greaterThan(0));
      expect(hedged, lessThan(60));
    });

    test('a confident character never hedges', () {
      for (var seed = 0; seed < 60; seed++) {
        final v = base
            .voice(VoiceTone.dry)
            .copyWith(confidence: VoiceLevel.high);
        final d = base.delivery.deliver(base.request(v, seed: seed));
        expect(unsureHedges.any(d.text.contains), isFalse);
      }
    });
  });

  group('the new tones are stored and read safely', () {
    test('they round-trip through the voice record', () {
      for (final t in VoiceTone.values) {
        final v = base.voice(t);
        expect(VoiceProfile.fromJson(v.toJson())!.tone, t);
      }
    });

    test('a tone this version does not know falls back to the default', () {
      final json = base.voice(VoiceTone.timid).toJson();
      json['tone'] = 'mercurial';
      expect(VoiceProfile.fromJson(json)!.tone, VoiceTone.neutral);
    });
  });

  group('the voice sample', () {
    test('is three moments, the same every time, and differs by tone', () {
      final byTone = {
        for (final t in VoiceTone.values)
          t: VoiceSample.of(base.voice(t)).join('\n'),
      };
      for (final t in VoiceTone.values) {
        final a = VoiceSample.of(base.voice(t));
        expect(a, hasLength(3));
        expect(a, VoiceSample.of(base.voice(t)));
        expect(a.every((l) => l.trim().isNotEmpty), isTrue);
      }
      expect(byTone.values.toSet().length, greaterThanOrEqualTo(9));
    });
  });

  group('the shared lines are in each tone\'s voice', () {
    test('every manner has remarks, a callback and doorways of its own', () {
      for (final t in MannerBanks.manners) {
        final b = MannerShared.of(t)!;
        expect(b.reflections, hasLength(EmotionFamily.values.length));
        for (final r in b.reflections) {
          expect(r, hasLength(2), reason: t.name);
        }
        expect(b.contrast, hasLength(2));
        expect(b.back, contains('{W}'));
        expect(b.backCount, allOf(contains('{O}'), contains('{W}')));
        expect(b.doorways, hasLength(TopicAccess.values.length));
        for (final d in b.doorways) {
          expect(d, hasLength(2));
        }
      }
    });

    test('a manner is mostly its own lines here too', () {
      for (final t in MannerBanks.manners) {
        final mine = MannerShared.of(t)!.all.toList();
        final others = {
          for (final o in MannerBanks.manners.where((o) => o != t))
            ...MannerShared.of(o)!.all,
        };
        final own = mine.where((l) => !others.contains(l)).length;
        expect(own / mine.length, greaterThan(0.9), reason: t.name);
      }
    });

    test('a remark on a feeling is the tone\'s, and never the shared one', () {
      final heard = Heard.from(
        const RuleBasedResponseReader().read('I was terrified'),
      );
      const neutral = <String>{
        'Fear usually points at something.',
        'Fear is easier to see once it has a shape.',
      };
      for (final t in MannerBanks.manners) {
        final bank = MannerShared.of(t)!.reflection(EmotionFamily.fear);
        for (var turn = 0; turn < 12; turn++) {
          final line = Listening.reflection(
            heard,
            tone: ListenTone.values.byName(t.name),
            seed: GenerationSeed.root(3),
            turn: turn,
          );
          expect(bank, contains(line), reason: t.name);
          expect(neutral, isNot(contains(line)));
        }
      }
    });

    test('a callback and a doorway are in the tone too', () {
      final said = Heard.from(
        const RuleBasedResponseReader().read('I was terrified'),
      );
      for (final t in [
        ListenTone.timid,
        ListenTone.blunt,
        ListenTone.playful,
      ]) {
        final b = MannerShared.of(t)!;
        String? back;
        for (var turn = 0; turn < 40 && back == null; turn++) {
          back = Listening.callback(
            said,
            [said],
            tone: t,
            seed: GenerationSeed.root(5),
            turn: turn,
          );
        }
        expect(back, isNotNull, reason: t.name);
        expect(back, b.back.replaceAll('{W}', 'Terrified'));
      }
      final v = base.voice(VoiceTone.timid);
      final closing = base.delivery.deliver(
        base.request(
          v,
          behaviour: RelationshipBehaviour.deflect,
          q: null,
          doorway: TopicAccess.personal,
        ),
      );
      final door = closing.lines.firstWhere((l) => l.kind == LineKind.doorway);
      expect(
        MannerShared.of(ListenTone.timid)!.doorway(TopicAccess.personal),
        contains(door.text),
      );
    });
  });
}
