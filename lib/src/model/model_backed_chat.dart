/// Greetings and light conversation, worded by your own model when it can be, and by
/// the authored lines when it cannot.
///
/// Every reply from the model goes through [ChatGuard]. If the server cannot be
/// reached, refuses the token, is at a limit, takes too long, or says something the
/// guard refuses, the authored line is used and [ChatReply.fallback] says why. A
/// character never fails to answer, and an unchecked reply never shows.
library;

import 'chat_fallback.dart';
import 'chat_guard.dart';
import 'chat_models.dart';
import 'model_exception.dart';
import 'own_model_client.dart';

class ModelBackedChat {
  const ModelBackedChat({
    required this.client,
    this.guard = const ChatGuard(),
    this.fallback = const ChatFallback(),
  });

  final OwnModelClient client;
  final ChatGuard guard;
  final ChatFallback fallback;

  Future<ChatReply> say(ChatRequest request) async {
    final String reply;
    try {
      reply = await client.say(request);
    } on ModelException catch (e) {
      return ChatReply(fallback.say(request), fallback: e.failure.name);
    } on Object {
      return ChatReply(
        fallback.say(request),
        fallback: ModelFailure.other.name,
      );
    }
    final checked = guard.check(request, reply);
    final text = checked.text;
    if (text == null) {
      return ChatReply(
        fallback.say(request),
        fallback: 'rejected: ${checked.reason}',
      );
    }
    return ChatReply(text, usedModel: true);
  }
}
