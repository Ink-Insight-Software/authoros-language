/// Live conversation: what the prompt holds, what the checks refuse, and what a
/// character says when the model cannot be used. No test reaches a network or a real
/// model; a scripted model stands in, so these show the guarantees, not the quality of
/// any model's writing.
library;

import 'dart:async';
import 'dart:convert';

import 'package:authoros_language/authoros_language.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

class Scripted implements LiveModel {
  Scripted(this.lines);
  final List<Object> lines; // String, or an Exception to throw
  final systems = <String>[];
  final sent = <List<LiveMessage>>[];
  int calls = 0;

  @override
  Future<String> complete({
    required String system,
    required List<LiveMessage> messages,
    required int maxTokens,
  }) async {
    systems.add(system);
    sent.add(messages);
    final v = lines[calls < lines.length ? calls : lines.length - 1];
    calls++;
    if (v is Exception) throw v;
    return v as String;
  }
}

LiveTurnInput turn({
  String? ask,
  String? question,
  RelationshipBehaviour behaviour = RelationshipBehaviour.trust,
  List<LiveLine> history = const [],
  List<KnownFact> facts = const [],
  List<StoryFact> story = const [],
  RelationshipStage stage = RelationshipStage.newStage,
  LiveMode mode = LiveMode.canon,
  List<String> draft = const [],
}) => LiveTurnInput(
  characterName: 'Mara',
  pronouns: 'she/her',
  tone: VoiceTone.dry,
  length: CommunicationLength.measured,
  stage: stage,
  facts: facts,
  storyFacts: story,
  mode: mode,
  history: history,
  authorText: ask,
  directive: LiveDirective(
    behaviour: behaviour,
    question: question,
    draft: draft,
    authorAsked: ask != null && ask.trim().endsWith('?'),
  ),
);

void main() {
  group('prompt', () {
    test('holds only what the character knows, and says so', () {
      final p = LivePrompt.system(
        turn(
          facts: const [
            KnownFact(FactTopic.fear, 'Mara fears the sea.', tender: true),
            KnownFact(FactTopic.trait, 'Mara is stubborn.'),
          ],
          story: const [
            StoryFact(
              text: 'Iven told Mara the ledger was gone.',
              state: 'believes',
            ),
          ],
        ),
      );
      expect(p, contains('Mara is stubborn.'));
      expect(p, isNot(contains('fears the sea')), reason: 'tender, new stage');
      expect(p, contains('Iven told Mara the ledger was gone.'));
      expect(p, contains('could be wrong'));
      expect(p, contains('This list is your whole memory'));
    });

    test('tender facts open once the character is familiar', () {
      final p = LivePrompt.system(
        turn(
          stage: RelationshipStage.familiar,
          facts: const [
            KnownFact(FactTopic.fear, 'Mara fears the sea.', tender: true),
          ],
        ),
      );
      expect(p, contains('fears the sea'));
    });

    test(
      'the decided question is what to find out, in the character\'s words',
      () {
        final p = LivePrompt.system(turn(question: 'What do you want most?'));
        expect(p, contains('own words'));
        expect(p, isNot(contains('word for word')));
        expect(p, contains('What do you want most?'));
      },
    );

    test('a what-if conversation says nothing is canon', () {
      expect(
        LivePrompt.system(turn(mode: LiveMode.hypothetical)),
        contains('what-if'),
      );
    });

    test('messages alternate and start and end with the author', () {
      final m = LivePrompt.messages(
        turn(
          ask: 'Why the sea?',
          history: const [
            LiveLine(LiveSpeaker.character, 'Hello.'),
            LiveLine(LiveSpeaker.author, 'Hi.'),
            LiveLine(LiveSpeaker.character, 'Well.'),
          ],
        ),
      );
      expect(m.first.role, 'user');
      expect(m.last.role, 'user');
      for (var i = 1; i < m.length; i++) {
        expect(m[i].role, isNot(m[i - 1].role));
      }
      expect(m.last.content, 'Why the sea?');
    });

    test('when the character opens, the first message is still the author', () {
      final m = LivePrompt.messages(turn());
      expect(m, hasLength(1));
      expect(m.single.role, 'user');
    });
  });

  group('guard', () {
    const g = LiveGuard();

    test('passes a plain in-voice line', () {
      final c = g.check(
        turn(ask: 'Why the sea?'),
        'The sea keeps its own counsel. So do I.',
      );
      expect(c.ok, isTrue, reason: c.problems.join(','));
    });

    for (final (label, text) in [
      ('markup', '**Fine.** Ask on.'),
      ('a list', '- one\n- two'),
      ('model talk', 'As an AI, I cannot say.'),
      ('mentions the vendor', 'I was made by Anthropic, you know.'),
      ('cut off', 'The thing about the sea is that it'),
      ('emoji', 'Fine 😀.'),
    ]) {
      test('refuses $label', () {
        expect(g.check(turn(ask: 'Why?'), text).ok, isFalse);
      });
    }

    test('strips wrapping quotation marks instead of failing', () {
      final c = g.check(turn(ask: 'Why?'), '"I would rather not say."');
      expect(c.ok, isTrue);
      expect(c.text, 'I would rather not say.');
    });

    test('canon: a made-up name is refused; what-if reports it', () {
      const text = 'My brother Tobias would know.';
      final canon = g.check(turn(ask: 'Who knows?'), text);
      expect(canon.ok, isFalse);
      expect(canon.problems.join(), contains('Tobias'));
      final wi = g.check(
        turn(ask: 'Who knows?', mode: LiveMode.hypothetical),
        text,
      );
      expect(wi.ok, isTrue);
      expect(wi.introduced, ['Tobias']);
    });

    test('a name the author used may be said back', () {
      final c = g.check(
        turn(
          ask: 'Tell me about Iven.',
          story: const [StoryFact(text: 'Iven sailed north.', state: 'knows')],
        ),
        'Iven sailed north, and I did not go.',
      );
      expect(c.ok, isTrue, reason: c.problems.join(','));
    });

    test('the reply ends with exactly one question, which may be reworded', () {
      final t = turn(ask: 'Hm.', question: 'What do you want most?');
      expect(g.check(t, 'Fair enough. What do you want most?').ok, isTrue);
      expect(g.check(t, 'Fair enough. What is it you are after?').ok, isTrue);
      expect(
        g.check(t, 'Fair enough. Say more.').ok,
        isFalse,
        reason: 'no question',
      );
      expect(
        g.check(t, 'What do you want most? And why?').ok,
        isFalse,
        reason: 'a second question',
      );
      expect(g.check(t, 'What do you want most? Fair enough.').ok, isFalse);
    });

    test('a question already asked is not asked again', () {
      final t = turn(
        ask: 'Hm.',
        question: 'What do you want most?',
        history: const [
          LiveLine(LiveSpeaker.character, 'Right. What is it you are after?'),
        ],
      );
      expect(g.check(t, 'Fair enough. What is it you are after?').ok, isFalse);
      expect(
        g.check(t, 'Fair enough. And what would you give for it?').ok,
        isTrue,
      );
    });

    test('no question it was not given; closing never asks', () {
      final plain = turn(ask: 'I see.');
      expect(g.check(plain, 'Do you, now?').ok, isFalse);
      final closing = turn(
        ask: 'Let us stop.',
        behaviour: RelationshipBehaviour.refuse,
      );
      expect(g.check(closing, 'Fine. Come back when you mean it.').ok, isTrue);
    });

    test('refuses handing the author back their own words, or a repeat', () {
      final t = turn(
        ask: 'You are stubborn about the sea and you always have been',
        history: const [
          LiveLine(LiveSpeaker.character, 'Leave the sea out of it, please.'),
        ],
      );
      expect(
        g
            .check(
              t,
              'You are stubborn about the sea and you always have been.',
            )
            .ok,
        isFalse,
      );
      expect(g.check(t, 'Leave the sea out of it, please.').ok, isFalse);
    });

    test('long replies are refused for a terse speaker', () {
      final t = LiveTurnInput(
        characterName: 'Mara',
        length: CommunicationLength.terse,
        directive: const LiveDirective(behaviour: RelationshipBehaviour.trust),
        authorText: 'Well?',
      );
      expect(g.check(t, '${List.filled(60, 'word').join(' ')}.').ok, isFalse);
    });
  });

  group('conversation', () {
    test('a good first reply is used and marked live', () async {
      final m = Scripted(['Hm. The sea, always the sea.']);
      final r = await LiveConversation(
        m,
      ).reply(turn(ask: 'Why the sea?'), fallback: 'I would rather not say.');
      expect(r.live, isTrue);
      expect(r.text, 'Hm. The sea, always the sea.');
      expect(m.calls, 1);
    });

    test('a bad reply is retried once, with the reason, then used', () async {
      final m = Scripted(['As an AI I cannot.', 'Not today.']);
      final r = await LiveConversation(
        m,
      ).reply(turn(ask: 'Why?'), fallback: 'x');
      expect(r.live, isTrue);
      expect(r.text, 'Not today.');
      expect(m.calls, 2);
      expect(m.systems.last, contains('could not be used because'));
      expect(m.systems.last, contains('talks about being a model'));
    });

    test('two bad replies fall back to the engine wording', () async {
      final m = Scripted(['**no**', '**no**']);
      final r = await LiveConversation(
        m,
      ).reply(turn(ask: 'Why?'), fallback: 'I would rather not say.');
      expect(r.live, isFalse);
      expect(r.text, 'I would rather not say.');
      expect(r.fallbackReason, 'checks');
      expect(r.problems, isNotEmpty);
    });

    for (final f in ModelFailure.values) {
      test('model failure ${f.name} falls back without retrying', () async {
        final m = Scripted([ModelException(f)]);
        final r = await LiveConversation(
          m,
        ).reply(turn(ask: 'Why?'), fallback: 'Fallback line.');
        expect(r.text, 'Fallback line.');
        expect(r.live, isFalse);
        expect(r.fallbackReason, f.name);
        expect(m.calls, 1);
      });
    }

    test('an unexpected error falls back too', () async {
      final r = await LiveConversation(
        Scripted([StateError('boom')]),
      ).reply(turn(ask: 'Why?'), fallback: 'Fallback line.');
      expect(r.text, 'Fallback line.');
    });

    test(
      'a story check can refuse a reply, and a throwing one does not decide',
      () async {
        final m = Scripted(['Iven stole it.', 'I would not say.']);
        final r = await LiveConversation(m).reply(
          turn(
            ask: 'Who stole it?',
            story: const [StoryFact(text: 'Iven stole it.', state: 'knows')],
          ),
          fallback: 'x',
          storyCheck: (t) =>
              t.contains('stole') ? ['contradicts the story'] : [],
        );
        expect(r.text, 'I would not say.');
        expect(m.systems.last, contains('contradicts the story'));
        final r2 = await LiveConversation(Scripted(['Fine.'])).reply(
          turn(ask: 'Well?'),
          fallback: 'x',
          storyCheck: (_) => throw StateError('reader broke'),
        );
        expect(r2.live, isTrue);
      },
    );
  });

  group('story grounding', () {
    EntityRegistry reg() => EntityRegistry(const [
      ProjectEntity(
        id: 'char_mara',
        type: EntityType.character,
        names: ['Mara'],
        pronouns: 'she',
      ),
      ProjectEntity(
        id: 'char_iven',
        type: EntityType.character,
        names: ['Iven'],
        pronouns: 'he',
      ),
      ProjectEntity(
        id: 'char_edda',
        type: EntityType.character,
        names: ['Edda'],
        pronouns: 'she',
      ),
    ]);

    StoryGrounder grounder() {
      final index = StoryIndex(reg())
        ..ingest(
          'c1',
          'Mara told Iven that Edda stole the ledger.',
          storyTimeId: 'chapter_01',
        )
        ..ingest(
          'c2',
          'Edda watched Mara hide the key.',
          storyTimeId: 'chapter_02',
        )
        ..ingest(
          'c3',
          'Mara hid the key.',
          kind: SourceKind.canon,
          storyTimeId: 'chapter_03',
        );
      return StoryGrounder(index);
    }

    test(
      'lists what a character knows or believes, in the author\'s words',
      () {
        final f = grounder().factsFor('char_iven');
        expect(
          f.map((x) => x.text),
          contains('Mara told Iven that Edda stole the ledger.'),
        );
        expect(
          f.firstWhere((x) => x.text.contains('ledger')).state,
          'believes',
        );
      },
    );

    test('a character is told nothing from before they could know it', () {
      final g = grounder();
      expect(g.factsFor('char_edda', at: 'chapter_01'), isEmpty);
      expect(
        g.factsFor('char_edda').map((x) => x.text),
        contains('Edda watched Mara hide the key.'),
      );
    });

    test('a character who knows nothing is told nothing', () {
      expect(grounder().factsFor('char_nobody'), isEmpty);
    });

    test('reading a reply that is fine, or unreadable, raises nothing', () {
      final g = grounder();
      expect(g.problemsIn('char_mara', 'I hid it somewhere safe.'), isEmpty);
      expect(g.problemsIn('char_mara', '???'), isEmpty);
      expect(g.problemsIn('char_mara', ''), isEmpty);
    });

    test('a reply that denies what the story says is caught', () {
      final g = grounder();
      expect(
        g.problemsIn('char_mara', 'I did not hide the key.').single,
        contains('contradicts the story'),
      );
      expect(g.problemsIn('char_mara', 'I hid the key.'), isEmpty);
    });

    test(
      'stating what the story holds but the character never learned is caught',
      () {
        final g = grounder();
        // Iven was never told about the key.
        expect(
          g.problemsIn('char_iven', 'Mara hid the key.').single,
          contains('does not know'),
        );
        // Mara did it, so she knows.
        expect(g.problemsIn('char_mara', 'I hid the key.'), isEmpty);
      },
    );
  });

  group('hosted model', () {
    HostedConversationModel host(
      Future<http.Response> Function(http.Request) h, {
      Uri? at,
    }) => HostedConversationModel(
      endpoint:
          at ?? Uri.parse('https://chat.example.test/.netlify/functions/chat'),
      client: MockClient(h),
      timeout: const Duration(seconds: 2),
    );

    Future<String> ask(HostedConversationModel m) => m.complete(
      system: 'You are Mara.',
      messages: const [LiveMessage('user', 'Hello')],
      maxTokens: 100,
    );

    test('sends the prompt and returns the text', () async {
      late Map<String, dynamic> sent;
      final m = host((r) async {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        expect(r.headers.containsKey('authorization'), isFalse);
        return http.Response(jsonEncode({'text': 'Hm.'}), 200);
      });
      expect(await ask(m), 'Hm.');
      expect(sent['system'], 'You are Mara.');
      expect(sent['max_tokens'], 100);
      expect((sent['messages'] as List).single, {
        'role': 'user',
        'content': 'Hello',
      });
    });

    for (final (code, failure) in [
      (401, ModelFailure.unauthorized),
      (403, ModelFailure.unauthorized),
      (429, ModelFailure.limited),
      (500, ModelFailure.other),
    ]) {
      test('status $code is ${failure.name}', () async {
        final m = host((_) async => http.Response('no', code));
        await expectLater(
          ask(m),
          throwsA(
            isA<ModelException>().having((e) => e.failure, 'failure', failure),
          ),
        );
      });
    }

    test('a refusal, an empty reply and junk are named', () async {
      Future<void> expectFailure(String body, ModelFailure f) => expectLater(
        ask(host((_) async => http.Response(body, 200))),
        throwsA(isA<ModelException>().having((e) => e.failure, 'failure', f)),
      );
      await expectFailure(jsonEncode({'refused': true}), ModelFailure.refused);
      await expectFailure(jsonEncode({'text': '  '}), ModelFailure.empty);
      await expectFailure('not json', ModelFailure.other);
    });

    test('a network error and a timeout are named', () async {
      await expectLater(
        ask(host((_) async => throw StateError('down'))),
        throwsA(
          isA<ModelException>().having(
            (e) => e.failure,
            'f',
            ModelFailure.unreachable,
          ),
        ),
      );
      await expectLater(
        ask(host((_) => Completer<http.Response>().future)),
        throwsA(
          isA<ModelException>().having(
            (e) => e.failure,
            'f',
            ModelFailure.timedOut,
          ),
        ),
      );
    });

    test('plain http is refused except for this machine', () {
      expect(
        () => HostedConversationModel(
          endpoint: Uri.parse('http://example.test/x'),
        ),
        throwsArgumentError,
      );
      expect(
        () => HostedConversationModel(
          endpoint: Uri.parse('http://localhost:8888/x'),
        ),
        returnsNormally,
      );
    });

    test('the token goes only in a header', () async {
      final m = HostedConversationModel(
        endpoint: Uri.parse('https://chat.example.test/x'),
        token: 'sekrit',
        client: MockClient((r) async {
          expect(r.headers['authorization'], 'Bearer sekrit');
          expect(r.url.toString(), isNot(contains('sekrit')));
          expect(r.body, isNot(contains('sekrit')));
          return http.Response(jsonEncode({'text': 'Hm.'}), 200);
        }),
      );
      expect(await ask(m), 'Hm.');
    });
  });
}
