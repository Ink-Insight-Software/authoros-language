/// Delivery worded by a model, with the rule-based delivery as the floor.
///
/// A model is asked only for a turn that asks the author a question. Everything
/// else (opening a conversation, closing a topic, answering back) stays rule-based:
/// those are decided and bounded already. If the model cannot be reached, or its
/// reply fails [DeliveryGuard], the rule-based line is used and the result says
/// why, so a reply never fails to arrive and an unchecked one never shows.
library;

import '../language/delivery_service.dart';
import '../language/dialogue.dart';
import 'delivery_guard.dart';
import 'delivery_prompt.dart';
import 'model_client.dart';

/// How a turn was worded.
class DeliveryResult {
  const DeliveryResult(this.dialogue, {this.usedModel = false, this.fallback});

  final Dialogue dialogue;

  /// The model worded it, and the reply passed every check.
  final bool usedModel;

  /// Why the rule-based line was used when a model was expected, else null.
  final String? fallback;
}

/// Delivery that may take a moment, because a model may be asked.
abstract interface class AsyncDeliveryService {
  Future<DeliveryResult> deliver(DeliveryRequest request);
}

/// The rule-based delivery, as an [AsyncDeliveryService].
class RuleBasedAsyncDelivery implements AsyncDeliveryService {
  const RuleBasedAsyncDelivery([this.inner = const RuleBasedDelivery()]);

  final DeliveryService inner;

  @override
  Future<DeliveryResult> deliver(DeliveryRequest request) async =>
      DeliveryResult(inner.deliver(request));
}

class ModelBackedDelivery implements AsyncDeliveryService {
  const ModelBackedDelivery({
    required this.client,
    this.fallback = const RuleBasedDelivery(),
    this.guard = const DeliveryGuard(),
    this.characterName,
    this.maxTokens = 300,
  });

  final ModelClient client;
  final DeliveryService fallback;
  final DeliveryGuard guard;

  /// The character's own name for a request, which the model may use.
  final String? Function(DeliveryRequest request)? characterName;
  final int maxTokens;

  /// The prompt a request would send, for showing the author first. Null when this
  /// turn would not ask a model.
  ModelPrompt? promptFor(DeliveryRequest r) => asksModel(r)
      ? DeliveryPrompt.build(r, characterName: characterName?.call(r))
      : null;

  /// Whether a model is asked for [r].
  static bool asksModel(DeliveryRequest r) =>
      r.question != null &&
      !r.opening &&
      !r.answering &&
      !r.style.behaviour.closes;

  @override
  Future<DeliveryResult> deliver(DeliveryRequest r) async {
    if (!asksModel(r)) return DeliveryResult(fallback.deliver(r));
    final name = characterName?.call(r);
    final String reply;
    try {
      reply = await client.complete(
        DeliveryPrompt.build(r, characterName: name),
        maxTokens: maxTokens,
      );
    } on ModelException catch (e) {
      return DeliveryResult(fallback.deliver(r), fallback: e.failure.name);
    } on Object {
      return DeliveryResult(
        fallback.deliver(r),
        fallback: ModelFailure.other.name,
      );
    }
    final checked = guard.check(r, reply, characterName: name);
    final ok = checked.accepted;
    if (ok == null) {
      return DeliveryResult(
        fallback.deliver(r),
        fallback: 'rejected: ${checked.reason}',
      );
    }
    final lines = <DialogueLine>[
      if (ok.before.isNotEmpty) DialogueLine(LineKind.reaction, ok.before),
      DialogueLine(LineKind.question, ok.question),
    ];
    return DeliveryResult(
      Dialogue(
        lines: lines,
        behaviour: r.style.behaviour,
        question: ok.question,
        referencedFacts: [
          for (final f in r.knownFacts)
            if (ok.before.toLowerCase().contains(f.toLowerCase())) f,
        ],
      ),
      usedModel: true,
    );
  }
}
