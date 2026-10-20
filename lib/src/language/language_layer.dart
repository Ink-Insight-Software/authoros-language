/// The language layer as one thing the app is handed.
///
/// Everything upstream decides; this reads and voices. Both halves are interfaces,
/// so the rule-based layer here can be replaced without the engine changing.
library;

import 'character_answerer.dart';
import 'delivery_service.dart';
import 'response_reader.dart';

class LanguageLayer {
  const LanguageLayer({
    required this.delivery,
    required this.reader,
    this.answerer = const RuleBasedAnswerer(),
  });

  /// The rule-based layer. No model, no network, nothing leaves the device.
  const LanguageLayer.ruleBased()
    : delivery = const RuleBasedDelivery(),
      reader = const RuleBasedResponseReader(),
      answerer = const RuleBasedAnswerer();

  final DeliveryService delivery;
  final AuthorResponseReader reader;
  final CharacterAnswerer answerer;
}
