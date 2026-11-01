/// Why a call to the model server did not give a usable reply.
library;

enum ModelFailure {
  /// No token, or the server refused it.
  unauthorized,

  /// The server is at a limit.
  limited,

  /// No network, or the server could not be reached.
  unreachable,

  /// Took too long.
  timedOut,

  /// Answered, but with nothing usable.
  empty,

  /// Anything else the server reported.
  other,
}

class ModelException implements Exception {
  const ModelException(this.failure, [this.detail = '']);

  final ModelFailure failure;

  /// A short note for a developer. Never holds a token, a prompt or a reply.
  final String detail;

  @override
  String toString() =>
      'ModelException(${failure.name}${detail.isEmpty ? '' : ': $detail'})';
}
