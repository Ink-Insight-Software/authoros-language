/// The client against a real `model/serve.py`. Skipped unless a server is named:
///
///     python model/serve.py runs/v0 --token $AUTHOROS_MODEL_TOKEN &
///     AUTHOROS_MODEL_URL=http://127.0.0.1:8808 AUTHOROS_MODEL_TOKEN=... \
///       dart test test/own_model_live_test.dart
library;

import 'dart:io';

import 'package:authoros_language/authoros_language.dart';
import 'package:test/test.dart';

void main() {
  final url = Platform.environment['AUTHOROS_MODEL_URL'];
  final token = Platform.environment['AUTHOROS_MODEL_TOKEN'] ?? '';
  final skip = url == null || token.isEmpty
      ? 'set AUTHOROS_MODEL_URL and AUTHOROS_MODEL_TOKEN to run against a server'
      : false;

  OwnModelClient make([String? t]) => OwnModelClient(
    server: Uri.parse(url!),
    token: t ?? token,
    timeout: const Duration(seconds: 60),
  );

  test('the server answers', () async {
    expect(await make().healthy(), isTrue);
  }, skip: skip);

  test('a wrong token is refused, and the character still answers', () async {
    final c = make('not-the-token-at-all');
    await expectLater(
      c.say(const ChatRequest(moment: ChatMoment.chat, authorLine: 'Hello.')),
      throwsA(
        isA<ModelException>().having(
          (e) => e.failure,
          'failure',
          ModelFailure.unauthorized,
        ),
      ),
    );
    final r = await ModelBackedChat(client: c).say(
      const ChatRequest(moment: ChatMoment.chat, authorLine: 'Good morning!'),
    );
    expect(r.usedModel, isFalse);
    expect(r.fallback, 'unauthorized');
    expect(r.text, isNotNull);
  }, skip: skip);

  test(
    'every moment, tone and length gets a line back, checked or authored',
    () async {
      final chat = ModelBackedChat(client: make());
      var model = 0, authored = 0, silent = 0;
      for (final moment in ChatMoment.values) {
        for (final tone in VoiceTone.values) {
          final r = await chat.say(
            ChatRequest(
              moment: moment,
              authorLine: moment == ChatMoment.chat ? 'Good morning!' : '',
              tone: tone,
              length: CommunicationLength.terse,
            ),
          );
          if (r.text == null) {
            silent++;
            expect(
              moment,
              ChatMoment.farewell,
              reason: 'only a farewell may say nothing',
            );
          } else {
            r.usedModel ? model++ : authored++;
            expect(
              const ChatGuard().problems(r.text!, allowed: {'good', 'morning'}),
              isEmpty,
              reason: '$moment $tone: ${r.text}',
            );
          }
        }
      }
      // ignore: avoid_print
      print(
        'from the model: $model, authored fallback: $authored, nothing: $silent',
      );
      expect(
        model + authored + silent,
        ChatMoment.values.length * VoiceTone.values.length,
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
