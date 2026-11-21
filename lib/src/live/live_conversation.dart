/// One live turn: build the prompt, ask the model, check what comes back, retry once,
/// and fall back to the engine's own wording if it still is not right. A reply that
/// reaches the author is therefore either checked or authored.
library;

import '../model/model_exception.dart';
import 'live_guard.dart';
import 'live_models.dart';
import 'live_prompt.dart';

/// Whatever turns a prompt into text. Hosted behind a function that holds the API key;
/// a scripted fake in tests.
abstract class LiveModel {
  Future<String> complete({
    required String system,
    required List<LiveMessage> messages,
    required int maxTokens,
  });
}

class LiveConversation {
  LiveConversation(
    this.model, {
    this.guard = const LiveGuard(),
    this.maxAttempts = 2,
  }) : assert(maxAttempts >= 1);

  final LiveModel model;
  final LiveGuard guard;
  final int maxAttempts;

  /// A reply for [input]. [fallback] is what the rule-based engine would say; it is
  /// returned whenever the model cannot be used. [storyCheck] reads a reply against the
  /// story and returns what is wrong with it.
  Future<LiveReply> reply(
    LiveTurnInput input, {
    required String fallback,
    List<String> Function(String reply)? storyCheck,
  }) async {
    final messages = LivePrompt.messages(input);
    final baseSystem = LivePrompt.system(input);
    var problems = <String>[];
    var attempts = 0;
    for (var i = 0; i < maxAttempts; i++) {
      attempts++;
      final system = problems.isEmpty
          ? baseSystem
          : '$baseSystem\n\nYour last attempt could not be used because: '
                '${problems.join('; ')}. Say it again, fixing that, in the same '
                'voice.';
      final String raw;
      try {
        raw = await model.complete(
          system: system,
          messages: messages,
          maxTokens: LivePrompt.maxTokens(input.length),
        );
      } on ModelException catch (e) {
        return LiveReply(
          text: fallback,
          live: false,
          fallbackReason: e.failure.name,
          attempts: attempts,
        );
      } on Object catch (e) {
        return LiveReply(
          text: fallback,
          live: false,
          fallbackReason: 'error:${e.runtimeType}',
          attempts: attempts,
        );
      }
      final checked = guard.check(input, raw);
      problems = [...checked.problems];
      if (checked.ok && storyCheck != null) {
        try {
          problems.addAll(storyCheck(checked.text));
        } on Object {
          // A reading fault must not decide the reply either way.
        }
      }
      if (problems.isEmpty) {
        return LiveReply(
          text: checked.text,
          live: true,
          introduced: checked.introduced,
          attempts: attempts,
        );
      }
    }
    return LiveReply(
      text: fallback,
      live: false,
      fallbackReason: 'checks',
      attempts: attempts,
      problems: problems,
    );
  }
}
