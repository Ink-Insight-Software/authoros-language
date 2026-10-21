/// Model-backed delivery: what is sent, what is checked, and what happens when it
/// cannot be used. No test here reaches a network.
library;

import 'dart:convert';

import 'package:authoros_language/authoros_language.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'language_layer_test.dart' as base;

class FakeModel implements ModelClient {
  FakeModel(this.reply, {this.error});

  final String reply;
  final ModelException? error;
  final prompts = <ModelPrompt>[];

  @override
  String get provider => 'Fake';

  @override
  Future<String> complete(ModelPrompt prompt, {int maxTokens = 300}) async {
    prompts.add(prompt);
    if (error != null) throw error!;
    return reply;
  }
}

DeliveryRequest ask({
  String last = 'she forgave him because she was tired of carrying it',
  List<String> facts = const [],
  VoiceTone tone = VoiceTone.sardonic,
  RelationshipBehaviour behaviour = RelationshipBehaviour.tease,
  int turn = 3,
}) => base.request(
  base.voice(tone),
  behaviour: behaviour,
  last: last,
  facts: facts,
  turn: turn,
);

void main() {
  group('the prompt', () {
    test('carries the question, the author\'s words and the known facts', () {
      final r = ask(facts: ['Mara keeps a ledger']);
      final p = DeliveryPrompt.build(r, characterName: 'Mara');
      expect(p.user, contains(base.question));
      expect(p.user, contains('she forgave him'));
      expect(p.user, contains('Mara keeps a ledger'));
      expect(p.user, contains('CHARACTER: Mara'));
      expect(p.user, contains('sardonic'));
      expect(p.system, contains('word for word'));
    });

    test('says "nothing" when nothing is known, and sends no more', () {
      final p = DeliveryPrompt.build(ask());
      expect(p.user, contains('KNOWN'));
      expect(p.user, contains('- nothing'));
    });

    test('the preview is exactly what is sent', () {
      final p = DeliveryPrompt.build(ask());
      expect(p.preview, contains(p.system));
      expect(p.preview, contains(p.user));
    });

    test('differs by voice', () {
      final a = DeliveryPrompt.build(ask(tone: VoiceTone.timid)).user;
      final b = DeliveryPrompt.build(ask(tone: VoiceTone.blunt)).user;
      expect(a, isNot(b));
    });
  });

  group('the guard', () {
    const guard = DeliveryGuard();
    final r = ask(facts: ['Mara keeps a ledger']);
    String good(String before) => '$before ${base.question}';

    test('accepts a short reaction and the question word for word', () {
      final c = guard.check(
        r,
        good('Oh, tired of carrying it. How very relatable.'),
      );
      expect(c.accepted, isNotNull, reason: c.reason);
      expect(c.accepted!.question, base.question);
    });

    test('accepts just the question', () {
      expect(guard.check(r, base.question).accepted, isNotNull);
    });

    test('rejects a question that was changed, repeated or followed', () {
      expect(
        guard.check(r, 'Why did you make her forgive him?').reason,
        'question changed',
      );
      expect(
        guard.check(r, '${base.question} ${base.question}').reason,
        'question repeated',
      );
      expect(
        guard.check(r, '${base.question} Do tell me.').reason,
        'text after question',
      );
    });

    test('rejects a name, a place or a number that was not given', () {
      for (final reply in [
        'You and Tom again. ${base.question}',
        'Back in Lisbon, that was it. ${base.question}',
        'Twenty years of that, was it? ${base.question}',
        'It was in 1998, wasn\'t it. ${base.question}',
      ]) {
        final c = guard.check(r, reply);
        expect(c.accepted, isNull, reason: reply);
        expect(c.reason, startsWith('new name or number'));
      }
    });

    test(
      'allows the character\'s name, a known fact\'s words and the author\'s',
      () {
        final c = guard.check(
          r,
          good('Mara does keep a ledger. Carrying things, you said.'),
          characterName: 'Mara',
        );
        expect(c.accepted, isNotNull, reason: c.reason);
      },
    );

    test(
      'rejects markdown, labels, quotation, stage directions and length',
      () {
        for (final reply in [
          '**Sighs.** ${base.question}',
          'Mara: Well. ${base.question}',
          '"Well, then." ${base.question}',
          '- Well.\n- Then. ${base.question}',
          '${'A short one. ' * 6}${base.question}',
          '${'x' * 400} ${base.question}',
        ]) {
          expect(guard.check(r, reply).accepted, isNull, reason: reply);
        }
      },
    );

    test('rejects an empty reply', () {
      expect(guard.check(r, '   ').reason, 'empty');
    });
  });

  group('model-backed delivery', () {
    test('uses a reply that passes, as a reaction and the question', () async {
      final model = FakeModel(
        'Tired of carrying it. How noble. ${base.question}',
      );
      final r = ask();
      final result = await ModelBackedDelivery(client: model).deliver(r);
      expect(result.usedModel, isTrue);
      expect(result.fallback, isNull);
      expect(result.dialogue.question, base.question);
      expect(result.dialogue.lines.last.kind, LineKind.question);
      expect(result.dialogue.lines.last.text, base.question);
      expect(result.dialogue.lines.first.kind, LineKind.reaction);
      expect(model.prompts, hasLength(1));
    });

    test(
      'falls back to the rule-based line when the reply fails a check',
      () async {
        final model = FakeModel('You and Tom again. ${base.question}');
        final r = ask();
        final result = await ModelBackedDelivery(client: model).deliver(r);
        expect(result.usedModel, isFalse);
        expect(result.fallback, startsWith('rejected'));
        expect(result.dialogue.question, base.question);
        expect(result.dialogue.text, const RuleBasedDelivery().deliver(r).text);
      },
    );

    test(
      'falls back when the model cannot be reached, whatever the reason',
      () async {
        for (final f in ModelFailure.values) {
          final model = FakeModel('', error: ModelException(f));
          final result = await ModelBackedDelivery(
            client: model,
          ).deliver(ask());
          expect(result.usedModel, isFalse, reason: f.name);
          expect(result.fallback, f.name);
          expect(result.dialogue.question, base.question);
        }
      },
    );

    test('falls back on an unexpected error too', () async {
      final result = await ModelBackedDelivery(
        client: _Throws(),
      ).deliver(ask());
      expect(result.usedModel, isFalse);
      expect(result.dialogue.question, base.question);
    });

    test('never asks a model to open, close or answer', () async {
      final model = FakeModel('unused');
      final delivery = ModelBackedDelivery(client: model);
      final closing = await delivery.deliver(
        base.request(
          base.voice(VoiceTone.blunt),
          behaviour: RelationshipBehaviour.deflect,
          q: null,
          doorway: TopicAccess.surface,
        ),
      );
      final opening = await delivery.deliver(
        base.request(base.voice(VoiceTone.blunt), turn: 0, last: null),
      );
      expect(closing.usedModel, isFalse);
      expect(opening.usedModel, isFalse);
      expect(closing.fallback, isNull);
      expect(model.prompts, isEmpty);
    });

    test('shows the prompt a turn would send, and null when it sends none', () {
      final d = ModelBackedDelivery(client: FakeModel(''));
      expect(d.promptFor(ask()), isNotNull);
      expect(
        d.promptFor(base.request(base.voice(VoiceTone.blunt), q: null)),
        isNull,
      );
    });

    test('the rule-based async delivery is the same line', () async {
      final r = ask();
      final result = await const RuleBasedAsyncDelivery().deliver(r);
      expect(result.usedModel, isFalse);
      expect(result.dialogue.text, const RuleBasedDelivery().deliver(r).text);
    });
  });

  group('the Anthropic client', () {
    test(
      'sends the key as a header, the prompt as the body, and reads the text',
      () async {
        late http.Request seen;
        final client = AnthropicClient(
          apiKey: 'sk-test-key',
          client: MockClient((request) async {
            seen = request;
            return http.Response(
              jsonEncode({
                'content': [
                  {'type': 'text', 'text': 'Hello there.'},
                ],
              }),
              200,
            );
          }),
        );
        const prompt = ModelPrompt(system: 'SYS', user: 'USR');
        expect(await client.complete(prompt), 'Hello there.');
        expect(seen.headers['x-api-key'], 'sk-test-key');
        expect(seen.headers['anthropic-version'], isNotEmpty);
        final body = jsonDecode(seen.body) as Map;
        expect(body['system'], 'SYS');
        expect((body['messages'] as List).single, {
          'role': 'user',
          'content': 'USR',
        });
        expect(body['model'], 'claude-haiku-5-5');
        expect(seen.body, isNot(contains('sk-test-key')));
      },
    );

    Future<ModelFailure> failureOf(int status, [String body = '{}']) async {
      final client = AnthropicClient(
        apiKey: 'k',
        client: MockClient((_) async => http.Response(body, status)),
      );
      try {
        await client.complete(const ModelPrompt(system: '', user: ''));
      } on ModelException catch (e) {
        return e.failure;
      }
      fail('expected a failure');
    }

    test('names why it failed', () async {
      expect(await failureOf(401), ModelFailure.unauthorized);
      expect(await failureOf(403), ModelFailure.unauthorized);
      expect(await failureOf(429), ModelFailure.limited);
      expect(await failureOf(500), ModelFailure.other);
      expect(
        await failureOf(200, jsonEncode({'content': []})),
        ModelFailure.empty,
      );
      expect(await failureOf(200, 'not json'), ModelFailure.other);
    });

    test('no key means no request', () async {
      var called = false;
      final client = AnthropicClient(
        apiKey: '  ',
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        client.complete(const ModelPrompt(system: '', user: '')),
        throwsA(
          isA<ModelException>().having(
            (e) => e.failure,
            'failure',
            ModelFailure.unauthorized,
          ),
        ),
      );
      expect(called, isFalse);
    });

    test(
      'an unreachable network is reported, and the error never carries the key',
      () async {
        final client = AnthropicClient(
          apiKey: 'sk-secret',
          client: MockClient((_) async => throw Exception('sk-secret leaked')),
        );
        try {
          await client.complete(const ModelPrompt(system: '', user: ''));
          fail('expected a failure');
        } on ModelException catch (e) {
          expect(e.failure, ModelFailure.unreachable);
          expect(e.toString(), isNot(contains('sk-secret')));
        }
      },
    );
  });
}

class _Throws implements ModelClient {
  @override
  String get provider => 'Throws';

  @override
  Future<String> complete(ModelPrompt prompt, {int maxTokens = 300}) =>
      throw StateError('boom');
}
