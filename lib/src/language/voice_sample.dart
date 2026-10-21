/// A short sample of how a voice sounds, for the author to hear while they set it.
///
/// It is the real delivery, run on fixed words, so what the author hears is what
/// the character will say. It reads nothing about the story and names no one.
library;

import 'package:authoros_core/procedural/generation_seed.dart';

import '../questions/relationship_stage.dart';
import '../voice/relationship_behaviour.dart';
import '../voice/relationship_state.dart';
import '../voice/relationship_voice_composer.dart';
import '../voice/voice_profile.dart';
import 'delivery_service.dart';
import 'listening.dart';
import 'response_reader.dart';

class VoiceSample {
  const VoiceSample._();

  /// What the author said, in the sample.
  static const said = 'I was terrified, and I could not tell anyone.';

  static const _asks = 'What happened next?';

  /// Three short moments in [voice]: a greeting, a reply to [said], and a
  /// character declining to go somewhere. Always the same for the same voice.
  static List<String> of(VoiceProfile voice) {
    const composer = RelationshipVoiceComposer();
    final relationship = AuthorCharacterRelationship(
      projectId: voice.projectId,
      characterId: voice.characterId,
      sharedSessions: 4,
      scores: {for (final d in RelationshipDimension.values) d: 0.5},
    );

    DeliveryStyle style(RelationshipBehaviour b) => composer.compose(
      voice: voice,
      relationship: relationship,
      choice: BehaviourChoice(behaviour: b, reasons: const []),
    );

    DeliveryRequest request(
      RelationshipBehaviour b, {
      int turn = 3,
      String? question = _asks,
      String? last,
      Heard? heard,
    }) => DeliveryRequest(
      style: style(b),
      voice: voice,
      stage: RelationshipStage.familiar,
      seed: GenerationSeed.root(11),
      turn: turn,
      question: question,
      lastAuthorText: last,
      heard: heard,
    );

    const delivery = RuleBasedDelivery();
    final heard = Heard.from(const RuleBasedResponseReader().read(said));
    return [
      delivery
          .deliver(
            request(RelationshipBehaviour.trust, turn: 0, question: _asks),
          )
          .text,
      delivery
          .deliver(
            request(RelationshipBehaviour.trust, last: said, heard: heard),
          )
          .text,
      delivery
          .deliver(
            request(RelationshipBehaviour.deflect, question: null, last: said),
          )
          .text,
    ];
  }
}
