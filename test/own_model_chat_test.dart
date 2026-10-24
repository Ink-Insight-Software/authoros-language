/// The Dart client for your own model server: what it sends, what it refuses to
/// show, and what a character says when the model cannot be used. No test here
/// reaches a network; `own_model_live_test.dart` talks to a real server when asked.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:authoros_language/authoros_language.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const token = 'test-token-123456';

OwnModelClient client(
  Future<http.Response> Function(http.Request) handler, {
  Uri? server,
  Duration timeout = const Duration(seconds: 5),
}) => OwnModelClient(
  server: server ?? Uri.parse('http://127.0.0.1:8808'),
  token: token,
  timeout: timeout,
  client: MockClient(handler),
);

http.Response said(String text) =>
    http.Response(jsonEncode({'text': text, 'model': 'runs/test'}), 200);

const chat = ChatRequest(
  moment: ChatMoment.chat,
  authorLine: 'Good morning!',
  tone: VoiceTone.sardonic,
  length: CommunicationLength.terse,
);

void main() {
  group('the server address', () {
    test('https is fine anywhere; http only for this machine', () {
      for (final ok in [
        'https://model.example.com',
        'https://model.example.com:8443/api',
        'http://127.0.0.1:8808',
        'http://localhost:8808',
        'http://[::1]:8808',
      ]) {
        expect(
          () => OwnModelClient(server: Uri.parse(ok), token: 't'),
          returnsNormally,
          reason: ok,
        );
      }
      for (final bad in [
        'http://model.example.com',
        'http://192.168.1.20:8808',
        'ftp://127.0.0.1',
        'model.example.com',
        'https://',
      ]) {
        expect(
          () => OwnModelClient(server: Uri.parse(bad), token: 't'),
          throwsArgumentError,
          reason: bad,
        );
      }
    });
  });

  group('the request', () {
    test(
      'goes to /v1/say with the token in a header and the moment in the body',
      () async {
        late http.Request seen;
        final c = client((r) async {
          seen = r;
          return said('Is it? Do tell me what is good about it.');
        });
        final line = await c.say(chat);
        expect(line, 'Is it? Do tell me what is good about it.');
        expect(seen.method, 'POST');
        expect(seen.url.toString(), 'http://127.0.0.1:8808/v1/say');
        expect(seen.headers['authorization'], 'Bearer $token');
        final body = jsonDecode(seen.body) as Map;
        expect(body['moment'], 'chat');
        expect(body['author'], 'Good morning!');
        expect(body['voice'], 'sardonic');
        expect(body['length'], 'terse');
        expect(body['temperature'], 0.8);
        expect(body['max_new_tokens'], 40);
        expect(seen.url.query, isEmpty);
        expect(
          seen.body,
          isNot(contains(token)),
          reason: 'the token is only a header',
        );
      },
    );

    test('keeps a path on the server address', () async {
      late Uri seen;
      final c = client((r) async {
        seen = r.url;
        return said('Hello.');
      }, server: Uri.parse('https://example.com/model/'));
      await c.say(chat);
      expect(seen.toString(), 'https://example.com/model/v1/say');
    });

    test(
      'every moment, tone and length is named as the server expects',
      () async {
        final bodies = <Map>[];
        final c = client((r) async {
          bodies.add(jsonDecode(r.body) as Map);
          return said('Hello.');
        });
        for (final m in ChatMoment.values) {
          for (final t in VoiceTone.values) {
            for (final l in CommunicationLength.values) {
              await c.say(ChatRequest(moment: m, tone: t, length: l));
            }
          }
        }
        expect(
          {for (final b in bodies) b['moment']},
          {'opening', 'returning', 'chat', 'farewell'},
        );
        expect({for (final b in bodies) b['voice']}.length, 12);
        expect(
          {for (final b in bodies) b['length']},
          {'terse', 'measured', 'expansive'},
        );
      },
    );

    test('healthy asks /healthz', () async {
      final c = client(
        (r) async =>
            http.Response('{"ok":true}', r.url.path == '/healthz' ? 200 : 404),
      );
      expect(await c.healthy(), isTrue);
      expect(
        await client((r) async => http.Response('', 500)).healthy(),
        isFalse,
      );
      expect(
        await client(
          (r) async => throw const SocketException('down'),
        ).healthy(),
        isFalse,
      );
    });
  });

  group('when the server cannot give a reply', () {
    Future<ModelException> failure(
      Future<http.Response> Function(http.Request) h, {
      Duration? timeout,
    }) async {
      try {
        await client(
          h,
          timeout: timeout ?? const Duration(seconds: 5),
        ).say(chat);
      } on ModelException catch (e) {
        return e;
      }
      fail('expected a failure');
    }

    test('names why', () async {
      expect(
        (await failure((_) async => http.Response('{}', 401))).failure,
        ModelFailure.unauthorized,
      );
      expect(
        (await failure((_) async => http.Response('{}', 403))).failure,
        ModelFailure.unauthorized,
      );
      expect(
        (await failure((_) async => http.Response('{}', 429))).failure,
        ModelFailure.limited,
      );
      expect(
        (await failure((_) async => http.Response('{}', 500))).failure,
        ModelFailure.other,
      );
      expect(
        (await failure((_) async => http.Response('{}', 400))).failure,
        ModelFailure.other,
      );
      expect(
        (await failure((_) async => throw const SocketException('x'))).failure,
        ModelFailure.unreachable,
      );
      expect(
        (await failure((_) async => http.Response('{"text":""}', 200))).failure,
        ModelFailure.empty,
      );
      expect(
        (await failure((_) async => http.Response('{"text":3}', 200))).failure,
        ModelFailure.empty,
      );
      expect(
        (await failure((_) async => http.Response('not json', 200))).failure,
        ModelFailure.other,
      );
      expect(
        (await failure((_) async => http.Response('[]', 200))).failure,
        ModelFailure.other,
      );
    });

    test('a slow server times out', () async {
      final e = await failure(
        (_) => Future.delayed(
          const Duration(milliseconds: 300),
          () => said('Hello.'),
        ),
        timeout: const Duration(milliseconds: 30),
      );
      expect(e.failure, ModelFailure.timedOut);
    });

    test('no token means no request', () async {
      var called = false;
      final c = OwnModelClient(
        server: Uri.parse('http://127.0.0.1:8808'),
        token: '   ',
        client: MockClient((_) async {
          called = true;
          return said('Hello.');
        }),
      );
      await expectLater(
        c.say(chat),
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

    test('an error never carries the token, the prompt or the reply', () async {
      for (final h in <Future<http.Response> Function(http.Request)>[
        (_) async => http.Response('secret reply $token', 500),
        (_) async => throw Exception('$token Good morning!'),
        (_) async => http.Response('$token not json', 200),
      ]) {
        try {
          await client(h).say(chat);
        } on ModelException catch (e) {
          expect(e.toString(), isNot(contains(token)));
          expect(e.toString(), isNot(contains('Good morning')));
          expect(e.toString(), isNot(contains('secret reply')));
        }
      }
    });
  });

  group('the guard', () {
    const guard = ChatGuard();

    test(
      'judges every shared case as the authoring checker and the writing screen do',
      () {
        final cases =
            jsonDecode(File('model/writer/rule_cases.json').readAsStringSync())
                as List;
        expect(cases, isNotEmpty);
        for (final c in cases) {
          final text = (c as Map)['text'] as String;
          expect(guard.problems(text).isEmpty, c['ok'], reason: jsonEncode(c));
        }
      },
    );

    test('accepts a plain short reply', () {
      expect(
        guard.check(chat, 'Is it? Do tell me what is good about it.').text,
        isNotNull,
      );
      expect(
        guard.check(chat, 'Morning. I suppose.').text,
        'Morning. I suppose.',
      );
    });

    test('refuses a reply that only gives the author their own words back', () {
      expect(
        guard.check(chat, 'Good morning!').reason,
        'only repeats the author',
      );
      expect(
        guard.check(chat, ' good morning ').reason,
        'only repeats the author',
      );
      expect(guard.check(chat, 'Good morning to you.').text, isNotNull);
    });

    test(
      'lets the character say back a name the author used, and no other',
      () {
        const toldMe = ChatRequest(
          moment: ChatMoment.chat,
          authorLine: 'I saw Tom today.',
        );
        expect(guard.check(toldMe, 'Did you see Tom, then?').text, isNotNull);
        expect(
          guard.check(toldMe, 'Did you see Anna, then?').reason,
          'names someone or somewhere',
        );
      },
    );

    test('refuses an empty reply and a long one', () {
      expect(guard.check(chat, '   ').reason, 'empty');
      expect(guard.check(chat, List.filled(31, 'word').join(' ')).text, isNull);
      expect(
        guard.check(chat, List.filled(30, 'word').join(' ')).text,
        isNotNull,
      );
    });

    test('refuses more than one line', () {
      expect(
        guard.check(chat, 'Ah.\nThere you are.').reason,
        'more than one line',
      );
    });
  });

  group('a character answering', () {
    ChatReply? last;

    Future<ChatReply> ask(
      Future<http.Response> Function(http.Request) h, [
      ChatRequest r = chat,
    ]) async => last = await ModelBackedChat(client: client(h)).say(r);

    test('uses a reply that passes', () async {
      final r = await ask((_) async => said('Is it? Do tell me why.'));
      expect(r.usedModel, isTrue);
      expect(r.fallback, isNull);
      expect(r.text, 'Is it? Do tell me why.');
    });

    test(
      'uses an authored line when the reply fails a check, and says why',
      () async {
        final r = await ask((_) async => said('Ah, Tom. Back in 5 minutes.'));
        expect(r.usedModel, isFalse);
        expect(r.fallback, startsWith('rejected: '));
        expect(r.text, isNotNull);
        expect(r.text, isNot(contains('Tom')));
      },
    );

    test('uses an authored line for every kind of failure', () async {
      for (final h in <(String, Future<http.Response> Function(http.Request))>[
        ('unauthorized', (_) async => http.Response('{}', 401)),
        ('limited', (_) async => http.Response('{}', 429)),
        ('unreachable', (_) async => throw const SocketException('x')),
        ('other', (_) async => http.Response('{}', 500)),
        ('empty', (_) async => http.Response('{"text":" "}', 200)),
      ]) {
        final r = await ask(h.$2);
        expect(r.usedModel, isFalse, reason: h.$1);
        expect(r.fallback, h.$1);
        expect(r.text, isNotNull, reason: h.$1);
      }
    });

    test('an unexpected error is a fallback too, not a crash', () async {
      final r = await ModelBackedChat(
        client: OwnModelClient(
          server: Uri.parse('http://127.0.0.1:1'),
          token: token,
          client: MockClient((_) async => throw StateError('boom')),
        ),
      ).say(chat);
      expect(r.usedModel, isFalse);
      expect(r.text, isNotNull);
    });

    test(
      'the authored lines are the rule-based ones, in the character\'s tone',
      () async {
        for (final tone in VoiceTone.values) {
          for (final moment in [
            ChatMoment.opening,
            ChatMoment.returning,
            ChatMoment.chat,
          ]) {
            final r = await ask(
              (_) async => http.Response('{}', 500),
              ChatRequest(
                moment: moment,
                authorLine: 'Good morning!',
                tone: tone,
              ),
            );
            expect(r.text, isNotNull, reason: '$tone $moment');
            expect(r.text!.trim(), isNotEmpty);
            expect(r.text, isNot(contains('\n')));
          }
        }
      },
    );

    test('an opening and a welcome back differ, and replay the same', () async {
      Future<String?> line(ChatMoment m) async => (await ask(
        (_) async => http.Response('{}', 500),
        ChatRequest(moment: m, tone: VoiceTone.sardonic, seed: 3),
      )).text;
      expect(await line(ChatMoment.opening), await line(ChatMoment.opening));
      expect(
        await line(ChatMoment.opening),
        isNot(await line(ChatMoment.returning)),
      );
    });

    test(
      'a farewell has no authored line, so a failed one says nothing',
      () async {
        final r = await ask(
          (_) async => http.Response('{}', 500),
          const ChatRequest(
            moment: ChatMoment.farewell,
            authorLine: 'I should go now.',
          ),
        );
        expect(r.text, isNull);
        expect(r.fallback, 'other');
        final ok = await ask(
          (_) async => said('Do. I will try to bear it.'),
          const ChatRequest(
            moment: ChatMoment.farewell,
            authorLine: 'I should go now.',
          ),
        );
        expect(ok.text, 'Do. I will try to bear it.');
      },
    );

    test('what is sent is only the line, the voice and the moment', () async {
      Map<String, Object?>? body;
      await ask((r) async {
        body = (jsonDecode(r.body) as Map).cast<String, Object?>();
        return said('Hello.');
      });
      expect(body!.keys.toSet(), {
        'moment',
        'author',
        'voice',
        'length',
        'temperature',
        'max_new_tokens',
      });
      expect(last, isNotNull);
    });
  });
}
