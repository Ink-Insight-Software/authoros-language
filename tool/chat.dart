/// Try your model server from the command line.
///
///     AUTHOROS_MODEL_TOKEN=... dart run tool/chat.dart \
///       --server http://127.0.0.1:8808 --moment chat --author "Good morning!" \
///       --tone sardonic --length terse
///
/// The token is read from the environment, not the command line, so it does not end
/// up in your shell history. Prints the line, and whether the model wrote it or the
/// authored fallback did, and why.
library;

import 'dart:io';

import 'package:authoros_language/authoros_language.dart';

Never usage(String why) {
  stderr.writeln(why);
  stderr.writeln(
    'usage: AUTHOROS_MODEL_TOKEN=... dart run tool/chat.dart --server URL '
    '[--moment opening|returning|chat|farewell] [--author TEXT] '
    '[--tone TONE] [--length terse|measured|expansive]',
  );
  exit(2);
}

Future<void> main(List<String> args) async {
  final opts = <String, String>{};
  for (var i = 0; i < args.length; i += 2) {
    if (!args[i].startsWith('--') || i + 1 >= args.length) {
      usage('bad argument: ${args[i]}');
    }
    opts[args[i].substring(2)] = args[i + 1];
  }
  final server = opts['server'];
  if (server == null) usage('--server is required');
  final token = Platform.environment['AUTHOROS_MODEL_TOKEN'] ?? '';
  if (token.isEmpty) usage('set AUTHOROS_MODEL_TOKEN');
  T pick<T extends Enum>(List<T> values, String key, T fallback) {
    final v = opts[key];
    if (v == null) return fallback;
    return values.firstWhere(
      (e) => e.name == v,
      orElse: () => usage('unknown --$key "$v"'),
    );
  }

  final OwnModelClient client;
  try {
    client = OwnModelClient(server: Uri.parse(server), token: token);
  } on ArgumentError catch (e) {
    usage('${e.message}');
  }
  final request = ChatRequest(
    moment: pick(ChatMoment.values, 'moment', ChatMoment.chat),
    authorLine: opts['author'] ?? '',
    tone: pick(VoiceTone.values, 'tone', VoiceTone.neutral),
    length: pick(
      CommunicationLength.values,
      'length',
      CommunicationLength.measured,
    ),
  );
  print('server ${await client.healthy() ? 'answers' : 'does NOT answer'}');
  final reply = await ModelBackedChat(client: client).say(request);
  print(reply.text ?? '(nothing to say)');
  print(
    reply.usedModel
        ? '[the model said this]'
        : '[authored fallback${reply.fallback == null ? '' : ': ${reply.fallback}'}]',
  );
  client.close();
}
