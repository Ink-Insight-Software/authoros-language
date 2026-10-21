/// The one thing a model-backed implementation needs from a model: text in, text
/// out. Everything else (what is asked, what is checked, what happens on failure)
/// lives in this package, so a provider can be swapped without touching it.
library;

/// What is sent: one system message and one user message. Public so an
/// application can show the author exactly this before anything leaves the device.
class ModelPrompt {
  const ModelPrompt({required this.system, required this.user});

  final String system;
  final String user;

  /// Everything that would be sent, as one readable block, for a preview.
  String get preview => 'INSTRUCTIONS\n$system\n\nCONTEXT\n$user';
}

abstract interface class ModelClient {
  /// A short name for where the text goes, for an author to read: "Anthropic".
  String get provider;

  /// Sends [prompt] and returns the model's text. Throws [ModelException] when it
  /// cannot: no network, a refused key, a limit, a timeout, an empty reply.
  Future<String> complete(ModelPrompt prompt, {int maxTokens = 300});
}

enum ModelFailure {
  /// No key, or the provider refused it.
  unauthorized,

  /// The provider's rate or spending limit.
  limited,

  /// No network, or the provider could not be reached.
  unreachable,

  /// Took too long.
  timedOut,

  /// Answered, but with nothing usable.
  empty,

  /// Anything else the provider reported.
  other,
}

class ModelException implements Exception {
  const ModelException(this.failure, [this.detail = '']);

  final ModelFailure failure;
  final String detail;

  @override
  String toString() =>
      'ModelException(${failure.name}${detail.isEmpty ? '' : ': $detail'})';
}
