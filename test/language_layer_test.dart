/// The language layer (plan 2.3 and 2.9): character-led delivery and reading the
/// author's words.
library;

import 'package:authoros_core/procedural/generation_seed.dart';
import 'package:authoros_language/authoros_language.dart';
import 'package:test/test.dart';

const delivery = RuleBasedDelivery();
const reader = RuleBasedResponseReader();
const composer = RelationshipVoiceComposer();
const question = 'Why did you make me forgive him?';

VoiceProfile voice(
  VoiceTone tone, {
  CommunicationLength length = CommunicationLength.measured,
  ConversationalRhythm rhythm = ConversationalRhythm.even,
  VoiceLevel affection = VoiceLevel.medium,
  VoiceLevel openness = VoiceLevel.medium,
  List<String> patterns = const [],
}) => VoiceProfile(
  projectId: 'p',
  characterId: 'c',
  tone: tone,
  communicationLength: length,
  rhythm: rhythm,
  affection: affection,
  openness: openness,
  speechPatterns: patterns,
);

AuthorCharacterRelationship relAt(double closeness, {int sessions = 0}) =>
    AuthorCharacterRelationship(
      projectId: 'p',
      characterId: 'c',
      sharedSessions: sessions,
      scores: {for (final d in RelationshipDimension.values) d: closeness},
    );

DeliveryRequest request(
  VoiceProfile v, {
  RelationshipBehaviour behaviour = RelationshipBehaviour.trust,
  RelationshipStage stage = RelationshipStage.familiar,
  int turn = 3,
  String? q = question,
  String? last = 'she forgave him because she was tired of carrying it',
  List<String> facts = const [],
  List<String> recent = const [],
  String? pattern,
  bool brief = false,
  TopicAccess? doorway,
  bool reluctant = false,
  double closeness = 0.5,
  int sessions = 0,
  bool relevantHistory = false,
  int seed = 7,
}) {
  final style = composer.compose(
    voice: v,
    relationship: relAt(closeness, sessions: sessions),
    relevantHistory: relevantHistory,
    choice: BehaviourChoice(
      behaviour: behaviour,
      reasons: const [],
      doorway: doorway,
      reluctant: reluctant,
    ),
  );
  return DeliveryRequest(
    style: style,
    voice: v,
    stage: stage,
    seed: GenerationSeed.root(seed),
    turn: turn,
    question: q,
    lastAuthorText: last,
    knownFacts: facts,
    recentFragments: recent,
    speechPattern: pattern,
    brief: brief,
    doorway: doorway,
  );
}

void main() {
  group('delivery', () {
    test('the question is placed word for word whatever the voice', () {
      for (final tone in VoiceTone.values) {
        for (final b in [
          RelationshipBehaviour.trust,
          RelationshipBehaviour.tease,
          RelationshipBehaviour.challenge,
          RelationshipBehaviour.correct,
          RelationshipBehaviour.vulnerability,
          RelationshipBehaviour.humour,
        ]) {
          final d = delivery.deliver(request(voice(tone), behaviour: b));
          expect(d.question, question, reason: '$tone $b');
          expect(d.text, contains(question), reason: '$tone $b');
          expect(
            d.lines.where((l) => l.kind == LineKind.question),
            hasLength(1),
          );
        }
      }
    });

    test('three strongly different voices say the same intent differently', () {
      final reserved = delivery.deliver(
        request(
          voice(VoiceTone.formal),
          behaviour: RelationshipBehaviour.trust,
        ),
      );
      final sarcastic = delivery.deliver(
        request(
          voice(VoiceTone.sardonic),
          behaviour: RelationshipBehaviour.tease,
        ),
      );
      final confrontational = delivery.deliver(
        request(
          voice(VoiceTone.blunt),
          behaviour: RelationshipBehaviour.challenge,
        ),
      );
      final texts = {reserved.text, sarcastic.text, confrontational.text};
      expect(texts, hasLength(3));
      for (final d in [reserved, sarcastic, confrontational]) {
        expect(d.question, question);
      }
      // Each draws on its own register.
      String leadOf(Dialogue d) =>
          d.fragments.where((f) => !f.startsWith('reaction')).first;
      expect(leadOf(reserved), contains('formal'));
      expect(leadOf(sarcastic), contains('sardonic'));
      expect(leadOf(confrontational), contains('blunt'));
      expect(leadOf(sarcastic), startsWith('tease'));
      expect(leadOf(confrontational), startsWith('challenge'));
    });

    test(
      'the same character is phrased differently to a stranger and a friend',
      () {
        final v = voice(VoiceTone.warm, openness: VoiceLevel.low);
        final stranger = delivery.deliver(
          request(
            v,
            stage: RelationshipStage.newStage,
            closeness: 0.05,
            turn: 3,
          ),
        );
        final friend = delivery.deliver(
          request(
            v,
            stage: RelationshipStage.deeplyConnected,
            closeness: 0.95,
            turn: 3,
          ),
        );
        expect(stranger.fragments.any((f) => f.startsWith('stranger')), isTrue);
        expect(friend.fragments.any((f) => f.startsWith('stranger')), isFalse);
        expect(stranger.text, isNot(friend.text));
      },
    );

    test(
      'nothing is said that is not the bank, the question, the author, or a given fact',
      () {
        final bank = RuleBasedDelivery.phrases;
        const facts = ['she grew up by the sea'];
        const last = 'she forgave him because she was tired of carrying it';
        for (var seed = 0; seed < 40; seed++) {
          for (final tone in VoiceTone.values) {
            final d = delivery.deliver(
              request(
                voice(
                  tone,
                  length: CommunicationLength.expansive,
                  affection: VoiceLevel.high,
                ),
                facts: facts,
                last: last,
                seed: seed,
                turn: seed % 7 + 1,
                closeness: 0.9,
                stage: RelationshipStage.trusted,
              ),
            );
            for (final line in d.lines) {
              final t = line.text;
              var rest = t.replaceAll(question, '').trim();
              rest = rest.replaceAll(RegExp(r'You said, "[^"]*"\.'), '').trim();
              rest = rest
                  .replaceAll('You told me before: she grew up by the sea.', '')
                  .trim();
              if (rest.isEmpty) continue;
              expect(
                bank.contains(rest),
                isTrue,
                reason: 'unsupported: "$rest" in "$t"',
              );
            }
            for (final f in d.referencedFacts) {
              expect(facts, contains(f));
            }
          }
        }
      },
    );

    test('an echo is the author\'s own words, never more', () {
      for (var seed = 0; seed < 40; seed++) {
        final d = delivery.deliver(
          request(
            voice(
              VoiceTone.warm,
              length: CommunicationLength.expansive,
              affection: VoiceLevel.veryHigh,
            ),
            seed: seed,
            closeness: 0.9,
          ),
        );
        for (final l in d.lines.where((l) => l.text.startsWith('You said'))) {
          final quoted = RegExp(r'"(.*?)…?"').firstMatch(l.text)!.group(1)!;
          expect(
            'she forgave him because she was tired of carrying it'.contains(
              quoted.replaceAll('…', ''),
            ),
            isTrue,
          );
        }
      }
    });

    test('facts are only used when history may be referenced', () {
      for (var seed = 0; seed < 30; seed++) {
        final d = delivery.deliver(
          request(
            voice(VoiceTone.neutral),
            facts: ['she grew up by the sea'],
            seed: seed,
            closeness: 0.0,
          ),
        );
        expect(d.referencedFacts, isEmpty, reason: 'seed $seed');
      }
    });

    test('repeated turns do not collapse into the same phrasing', () {
      final v = voice(VoiceTone.sardonic);
      var recent = <String>[];
      final leads = <String>[];
      for (var turn = 1; turn <= 9; turn++) {
        final d = delivery.deliver(
          request(
            v,
            behaviour: RelationshipBehaviour.challenge,
            turn: turn,
            recent: recent,
            last: null,
          ),
        );
        leads.add(d.text);
        recent = [...recent, ...d.fragments];
        if (recent.length > 6) recent = recent.skip(recent.length - 6).toList();
      }
      expect(leads.toSet().length, greaterThanOrEqualTo(3));
      for (var i = 1; i < leads.length; i++) {
        expect(leads[i], isNot(leads[i - 1]), reason: 'turn ${i + 1}');
      }
    });

    test('a fragment used recently is skipped while others remain', () {
      final first = delivery.deliver(
        request(voice(VoiceTone.warm), last: null),
      );
      final again = delivery.deliver(
        request(voice(VoiceTone.warm), last: null, recent: first.fragments),
      );
      expect(again.text, isNot(first.text));
    });

    test('the same request replays exactly', () {
      final a = delivery.deliver(request(voice(VoiceTone.dry)));
      final b = delivery.deliver(request(voice(VoiceTone.dry)));
      expect(a.text, b.text);
      expect(a.fragments, b.fragments);
    });

    test('closing behaviours do not ask, and offer a way in', () {
      for (final b in [
        RelationshipBehaviour.deflect,
        RelationshipBehaviour.redirect,
        RelationshipBehaviour.withhold,
        RelationshipBehaviour.refuse,
      ]) {
        final d = delivery.deliver(
          request(
            voice(VoiceTone.gentle),
            behaviour: b,
            q: null,
            doorway: TopicAccess.personal,
          ),
        );
        expect(d.asksQuestion, isFalse, reason: '$b');
        expect(d.lines.first.kind, LineKind.closing);
        expect(
          d.lines.any((l) => l.kind == LineKind.doorway),
          isTrue,
          reason: '$b',
        );
        expect(d.text.contains('?'), isFalse);
      }
    });

    test(
      'a question is never delivered by a closing behaviour even if one is given',
      () {
        final d = delivery.deliver(
          request(
            voice(VoiceTone.blunt),
            behaviour: RelationshipBehaviour.refuse,
            doorway: TopicAccess.surface,
          ),
        );
        expect(d.asksQuestion, isFalse);
        expect(d.text, isNot(contains(question)));
      },
    );

    test('doorways match how deep the character will still go', () {
      final text = {
        for (final a in TopicAccess.values)
          a: delivery
              .deliver(
                request(
                  voice(VoiceTone.neutral),
                  behaviour: RelationshipBehaviour.refuse,
                  q: null,
                  doorway: a,
                ),
              )
              .lines
              .last
              .text,
      };
      expect(text.values.toSet(), hasLength(TopicAccess.values.length));
    });

    test('an insisting author gets a reluctant lead', () {
      final d = delivery.deliver(
        request(voice(VoiceTone.warm), reluctant: true, last: null),
      );
      expect(d.fragments.any((f) => f.startsWith('reluctant')), isTrue);
      expect(d.question, question);
    });

    test('brief and terse keep it to the question', () {
      final brief = delivery.deliver(
        request(voice(VoiceTone.warm), brief: true),
      );
      expect(brief.text, question);
      final terse = delivery.deliver(
        request(voice(VoiceTone.warm, length: CommunicationLength.terse)),
      );
      expect(terse.text, question);
    });

    test(
      'no reaction beat for a brief author, a terse voice, or the first turn',
      () {
        bool hasReaction(Dialogue d) =>
            d.lines.any((l) => l.kind == LineKind.reaction);
        var seen = false;
        for (var seed = 0; seed < 60; seed++) {
          final lively = voice(
            VoiceTone.warm,
            length: CommunicationLength.expansive,
          );
          seen |= hasReaction(delivery.deliver(request(lively, seed: seed)));
          expect(
            hasReaction(
              delivery.deliver(request(lively, seed: seed, brief: true)),
            ),
            isFalse,
          );
          expect(
            hasReaction(delivery.deliver(request(lively, seed: seed, turn: 0))),
            isFalse,
          );
          expect(
            hasReaction(
              delivery.deliver(
                request(
                  voice(VoiceTone.warm, length: CommunicationLength.terse),
                  seed: seed,
                ),
              ),
            ),
            isFalse,
          );
        }
        expect(seen, isTrue, reason: 'the beat does appear when allowed');
      },
    );

    test(
      'a remembered fact shows up in the line and in referencedFacts together',
      () {
        var used = 0;
        for (var seed = 0; seed < 80; seed++) {
          final d = delivery.deliver(
            request(
              voice(VoiceTone.warm),
              facts: ['she grew up by the sea'],
              seed: seed,
              closeness: 0.95,
              sessions: 6,
              relevantHistory: true,
              stage: RelationshipStage.deeplyConnected,
            ),
          );
          final inText = d.lines.any((l) => l.kind == LineKind.memory);
          expect(d.referencedFacts.isNotEmpty, inText, reason: 'seed $seed');
          if (inText) used++;
        }
        expect(used, greaterThan(0));
      },
    );

    test('a clipped or halting voice puts the lead on its own line', () {
      final clipped = delivery.deliver(
        request(
          voice(VoiceTone.blunt, rhythm: ConversationalRhythm.clipped),
          last: null,
        ),
      );
      expect(clipped.lines.map((l) => l.kind), [
        LineKind.lead,
        LineKind.question,
      ]);
      final flowing = delivery.deliver(
        request(
          voice(VoiceTone.blunt, rhythm: ConversationalRhythm.flowing),
          last: null,
        ),
      );
      expect(flowing.lines.map((l) => l.kind), [LineKind.question]);
      expect(flowing.text, endsWith(question));
    });

    test('a speech pattern, when due, opens the line', () {
      final d = delivery.deliver(
        request(voice(VoiceTone.warm), pattern: 'Well, now,', last: null),
      );
      expect(d.text, contains('Well, now,'));
      expect(d.question, question);
    });

    test('the language layer bundle is rule-based and local', () {
      const layer = LanguageLayer.ruleBased();
      expect(layer.delivery, isA<RuleBasedDelivery>());
      expect(layer.reader, isA<RuleBasedResponseReader>());
    });
  });

  group('reading', () {
    AuthorResponseAnalysis read(
      String t, [
      ReaderContext c = const ReaderContext(),
    ]) => reader.read(t, context: c);

    test('raw text is kept exactly', () {
      const t = '  Hmm… "maybe" so   ';
      expect(read(t).rawText, t);
    });

    test('empty reads as nothing', () {
      final a = read('   ');
      expect(a.isEmpty, isTrue);
      expect(a.intents, isEmpty);
      expect(a.isEngaged, isFalse);
    });

    test('a one-word answer is an answer to nothing much', () {
      final a = read('Fine.');
      expect(a.intents, isNot(contains(ResponseIntent.answer)));
      expect(a.isEngaged, isFalse);
      expect(a.wordCount, 1);
    });

    test('a long exploratory answer is engaged and long', () {
      final text =
          '${List.filled(70, 'she kept walking along the shore').join(' ')}.';
      final a = read(text);
      expect(a.intents, contains(ResponseIntent.answer));
      expect(a.isEngaged, isTrue);
      expect(a.isLong, isTrue);
    });

    test('pure uncertainty is uncertainty, in all its forms', () {
      for (final t in [
        "I don't know",
        'idk',
        'Not sure.',
        'No idea',
        'maybe',
        "I'm not sure, honestly",
        'Hard to say',
        'I guess',
        "I don’t know",
      ]) {
        final a = read(t);
        expect(a.isUncertain, isTrue, reason: t);
        expect(a.isEngaged, isFalse, reason: t);
      }
    });

    test('an I-don\'t-know loop stays uncertain every time', () {
      for (final t in [
        "I don't know",
        'still not sure',
        'honestly no idea',
        'no clue',
      ]) {
        expect(read(t).isUncertain, isTrue, reason: t);
      }
    });

    test('hedged content is an answer but never settled', () {
      final a = read('Maybe she is afraid of her father');
      expect(a.isUncertain, isFalse);
      expect(a.isEngaged, isTrue);
      expect(a.hasSeveralPossibilities, isTrue);
    });

    test('"I don\'t know" followed by content is an answer', () {
      final a = read("I don't know, she just seems sad all the time");
      expect(a.isUncertain, isFalse);
      expect(a.isEngaged, isTrue);
    });

    test('multiple possibilities are recognised', () {
      for (final t in [
        'It could be grief, or maybe it is guilt',
        'Either she left him or he left her',
        'One possibility is the fire. Another possibility is the flood.',
        '1. She stayed 2. She ran',
        'What if she never forgave him',
        'thinking out loud here, she hates the sea',
      ]) {
        expect(read(t).hasSeveralPossibilities, isTrue, reason: t);
      }
      expect(
        read('She forgave him at the harbour').hasSeveralPossibilities,
        isFalse,
      );
    });

    test('corrections are recognised', () {
      for (final t in [
        'Actually, she was born in spring',
        'No, actually it was her brother',
        'I meant her sister',
        'Scratch that, he left first',
        "That's wrong, she never went back",
        'Not quite. She was twelve.',
      ]) {
        expect(read(t).isCorrection, isTrue, reason: t);
      }
    });

    test('"actually" in the middle of a sentence is not a correction', () {
      expect(read('She was actually rather kind to him').isCorrection, isFalse);
    });

    test('disagreement with the character is recognised', () {
      for (final t in [
        'I disagree, she would never do that',
        "You're wrong about him",
        "That's not what she'd do",
        "I don't think so",
        'No way',
      ]) {
        expect(read(t).isDisagreement, isTrue, reason: t);
      }
      expect(
        read('She disagreed with her father constantly').isDisagreement,
        isFalse,
      );
    });

    test('a question back to the character is recognised', () {
      for (final t in [
        'What do you think?',
        'Why do you ask that',
        'Would you have forgiven him?',
        'and you, what would you do',
      ]) {
        expect(read(t).asksBack, isTrue, reason: t);
      }
      expect(read('She asked herself that every night.').asksBack, isFalse);
    });

    test('a topic change is recognised', () {
      for (final t in [
        "Let's talk about the harbour instead",
        'Can we talk about her brother',
        'Change the subject please',
        'try a different approach',
        'ask me something else',
        'Move on',
      ]) {
        expect(read(t).changesTopic, isTrue, reason: t);
      }
    });

    test('stop and pause are recognised, in plain and polite forms', () {
      for (final t in [
        'Stop',
        'stop asking',
        'Please stop.',
        'enough',
        "that's enough for now",
        "I'm done",
        'Not now',
        'pause',
        'no more questions',
        'Honestly, stop.',
        'Okay, please stop!',
        "Honestly, stop. I don't want to talk about this.",
      ]) {
        final a = read(t);
        expect(a.wantsStop, isTrue, reason: t);
        expect(a.isEngaged, isFalse, reason: t);
      }
    });

    test('"stop" inside the author\'s story is not an instruction', () {
      for (final t in [
        "She couldn't stop crying after the funeral",
        'The clock stopped the night he left',
        'He would not stop until he found her',
      ]) {
        expect(read(t).wantsStop, isFalse, reason: t);
      }
    });

    test('skipping is recognised', () {
      for (final t in [
        'Skip',
        'pass',
        'next question',
        "I'd rather not say",
        'no comment',
      ]) {
        final a = read(t);
        expect(a.skips, isTrue, reason: t);
        expect(a.isEngaged, isFalse, reason: t);
      }
      expect(read('She would never pass the exam').skips, isFalse);
    });

    test('an ordinary answer is just an answer', () {
      final a = read('She left because her brother never wrote back');
      expect(a.intents, {ResponseIntent.answer});
      expect(a.isEngaged, isTrue);
    });

    test('a topic change with content keeps the answer too', () {
      final a = read(
        "She is jealous of him. Let's talk about the harbour though",
      );
      expect(a.changesTopic, isTrue);
      expect(a.intents, contains(ResponseIntent.answer));
    });
  });

  group('reading terms', () {
    ResponseTerms terms(String t, [ReaderContext c = const ReaderContext()]) =>
        reader.read(t, context: c).terms;

    test('fears are taken from how people say them', () {
      expect(
        terms('She is terrified of deep water because of the wreck').fears,
        {'deep water'},
      );
      expect(terms('He fears being forgotten.').fears, {'forgotten'});
      expect(terms('a lifelong fear of fire').fears, {'fire'});
    });

    test('motivations and values', () {
      expect(terms('She wants to clear her father\'s name').motivations, {
        "clear her father's name",
      });
      expect(terms('driven by revenge').motivations, {'revenge'});
      expect(terms('He believes in second chances').values, {'second chances'});
      expect(terms('loyal to her crew').values, {'crew'});
    });

    test('emotions are collected', () {
      expect(terms('She felt guilty and angry, and so ashamed').emotions, {
        'guilty',
        'angry',
        'ashamed',
      });
    });

    test(
      'names the project already holds are recognised, in their own spelling',
      () {
        const ctx = ReaderContext(
          people: {'Tom Hale'},
          places: {'Saltmarsh'},
          events: {'the wreck'},
        );
        final t = terms('after the wreck she took tom hale to saltmarsh', ctx);
        expect(t.people, {'Tom Hale'});
        expect(t.places, {'Saltmarsh'});
        expect(t.events, {'the wreck'});
      },
    );

    test('a one-letter name is not matched', () {
      const ctx = ReaderContext(people: {'A'});
      expect(terms('a boy ran home', ctx).people, isEmpty);
    });

    test('a name inside another word is not a mention', () {
      const ctx = ReaderContext(people: {'Tom'});
      expect(terms('the tomato crop failed', ctx).people, isEmpty);
    });

    test('phrases are capped and articles dropped', () {
      final f = terms(
        'afraid of the very long and winding road home again soon',
      ).fears;
      expect(f.single.split(' ').length, lessThanOrEqualTo(5));
      expect(f.single.startsWith('the '), isFalse);
    });
  });
}
