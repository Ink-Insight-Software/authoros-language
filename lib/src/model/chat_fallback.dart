/// What a character says when the model cannot be used: the authored lines, as before.
///
/// An opening is a greeting, a returning is a welcome back, and a chat reply is the
/// acknowledgement the rule-based layer already gives to what the author said. A
/// farewell has no authored line, so the fallback says nothing for it.
library;

import 'package:authoros_core/procedural/generation_seed.dart';

import '../language/delivery_service.dart';
import '../language/dialogue.dart';
import '../language/listening.dart';
import '../language/response_reader.dart';
import '../questions/relationship_stage.dart';
import '../voice/relationship_behaviour.dart';
import '../voice/relationship_state.dart';
import '../voice/relationship_voice_composer.dart';
import '../voice/voice_profile.dart';
import 'chat_models.dart';

class ChatFallback {
  const ChatFallback();

  /// One authored line for [r], or null when there is none.
  String? say(ChatRequest r) {
    if (r.moment == ChatMoment.farewell) return null;
    final voice = VoiceProfile(
      projectId: '',
      characterId: '',
      tone: r.tone,
      communicationLength: r.length,
    );
    const composer = RelationshipVoiceComposer();
    final relationship = AuthorCharacterRelationship(
      projectId: '',
      characterId: '',
      sharedSessions: 4,
      scores: {for (final d in RelationshipDimension.values) d: 0.5},
    );
    final heard = r.moment == ChatMoment.chat && r.authorLine.trim().isNotEmpty
        ? Heard.from(const RuleBasedResponseReader().read(r.authorLine))
        : null;
    final request = DeliveryRequest(
      style: composer.compose(
        voice: voice,
        relationship: relationship,
        choice: const BehaviourChoice(
          behaviour: RelationshipBehaviour.trust,
          reasons: [],
        ),
      ),
      voice: voice,
      stage: RelationshipStage.familiar,
      seed: GenerationSeed.root(r.seed),
      turn: r.moment == ChatMoment.chat && r.turn == 0 ? 1 : r.turn,
      // A placeholder: only the greeting and the acknowledgement are taken.
      question: 'x',
      lastAuthorText: heard == null ? null : r.authorLine,
      heard: heard,
      returning: r.moment == ChatMoment.returning,
    );
    final kinds = r.moment == ChatMoment.chat
        ? const {LineKind.reaction}
        : const {LineKind.greeting};
    final lines = [
      for (final l in const RuleBasedDelivery().deliver(request).lines)
        if (kinds.contains(l.kind)) l.text,
    ];
    if (lines.isEmpty) return null;
    // A greeting is one line; the scene line that can follow it is not wanted here.
    return r.moment == ChatMoment.chat ? lines.join(' ') : lines.first;
  }
}
