/// How well this character and this author know each other.
///
/// The second half of Phase 3's distinction (3.1): the voice is how the character
/// speaks; the relationship is how the character speaks *to this author*, and it
/// is the part that grows. It tracks familiarity, trust, openness, patience and
/// willingness to challenge (plan 3.3), and a count of shared history. The
/// stage the rest of the engine reads (`RelationshipStage`, New to Deeply
/// Connected) is derived from these, never set directly.
///
/// ## Not a game
///
/// The plan says raw scores are not shown by default and that the experience must
/// not become *visible game statistics* (3.3, Phase 3's pass criteria). So the
/// numbers are kept apart: [debugScores] is named for what it is, and what the
/// author can see is a [RelationshipSummary], a stage and the history of changes.
///
/// ## The author's controls
///
/// Evolution can be disabled, the relationship can be reset, a deleted
/// conversation stops being referred to, and the author can read and change what
/// the character's boundaries are (plan 3.8). Each of those is a method here, and
/// none of them touches the voice or the author's canon.
library;

import '../questions/relationship_stage.dart';

/// The version of the stored shape.
const int kRelationshipSchemaVersion = 1;

/// What the relationship is made of.
enum RelationshipDimension {
  familiarity,
  trust,
  openness,
  patience,
  challengeWillingness,
}

/// One change of stage, kept so the history of the relationship is not lost
/// (plan 3.3: *preserve historical relationship changes*).
class RelationshipChange {
  const RelationshipChange({
    required this.at,
    required this.from,
    required this.to,
    required this.reason,
    this.sessionId,
    this.sourceRemoved = false,
  });

  final DateTime at;
  final RelationshipStage from;
  final RelationshipStage to;

  /// A plain sentence of why.
  final String reason;

  /// The conversation that brought it about, if any.
  final String? sessionId;

  /// The conversation was deleted. The change stays, and no longer points at it.
  final bool sourceRemoved;

  RelationshipChange withoutSource() => RelationshipChange(
    at: at,
    from: from,
    to: to,
    reason: reason,
    sessionId: null,
    sourceRemoved: true,
  );

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'from': from.name,
    'to': to.name,
    'reason': reason,
    'sessionId': sessionId,
    'sourceRemoved': sourceRemoved,
  };

  static RelationshipChange? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['at']}');
    final from = _stage(json['from']);
    final to = _stage(json['to']);
    if (at == null || from == null || to == null) return null;
    return RelationshipChange(
      at: at,
      from: from,
      to: to,
      reason: json['reason'] is String ? json['reason'] as String : '',
      sessionId: json['sessionId'] is String
          ? json['sessionId'] as String
          : null,
      sourceRemoved: json['sourceRemoved'] == true,
    );
  }
}

RelationshipStage? _stage(Object? raw) {
  for (final stage in RelationshipStage.values) {
    if (stage.name == raw) return stage;
  }
  return null;
}

/// What the author is shown: a stage and how it came about. No numbers.
class RelationshipSummary {
  const RelationshipSummary({
    required this.stage,
    required this.label,
    required this.history,
    required this.evolutionEnabled,
  });

  final RelationshipStage stage;

  /// The stage in words, for the author.
  final String label;

  final List<RelationshipChange> history;
  final bool evolutionEnabled;
}

/// The relationship between one character and one author, in one project.
class AuthorCharacterRelationship {
  AuthorCharacterRelationship({
    required this.projectId,
    required this.characterId,
    Map<RelationshipDimension, double>? scores,
    this.sharedTurns = 0,
    this.sharedSessions = 0,
    this.history = const [],
    this.evolutionEnabled = true,
  }) : _scores = {
         for (final d in RelationshipDimension.values)
           d: (scores?[d] ?? _starting[d]!).clamp(0.0, 1.0),
       };

  /// A relationship that has just begun.
  factory AuthorCharacterRelationship.fresh({
    required String projectId,
    required String characterId,
  }) => AuthorCharacterRelationship(
    projectId: projectId,
    characterId: characterId,
  );

  final String projectId;
  final String characterId;
  final Map<RelationshipDimension, double> _scores;

  /// Turns spoken between them, across every conversation.
  final int sharedTurns;

  /// Conversations they have had.
  final int sharedSessions;

  final List<RelationshipChange> history;

  /// Whether the relationship may change. Off, it stays where the author left it
  /// (plan 3.8: *inspect, edit, reset or disable relationship evolution*).
  final bool evolutionEnabled;

  /// Where each dimension starts. Patience and willingness to challenge begin
  /// in the middle: a stranger is neither patient nor impatient yet.
  static const Map<RelationshipDimension, double> _starting = {
    RelationshipDimension.familiarity: 0.0,
    RelationshipDimension.trust: 0.0,
    RelationshipDimension.openness: 0.1,
    RelationshipDimension.patience: 0.5,
    RelationshipDimension.challengeWillingness: 0.3,
  };

  /// The raw numbers. **Not for the author's eyes**: this exists for tests and
  /// for the evolution rules, and the interface shows [summary] instead.
  Map<RelationshipDimension, double> get debugScores =>
      Map.unmodifiable(_scores);

  double score(RelationshipDimension dimension) => _scores[dimension]!;

  /// A single measure of how close they are, from zero to one.
  double get closeness =>
      0.4 * score(RelationshipDimension.trust) +
      0.3 * score(RelationshipDimension.familiarity) +
      0.2 * score(RelationshipDimension.openness) +
      0.1 * (sharedSessions / 12).clamp(0.0, 1.0);

  /// The stage the rest of the engine reads.
  RelationshipStage get stage => stageForCloseness(closeness);

  /// The closeness at which each stage begins. Every gap is wider than one
  /// evolution step can cover, so no single event can skip a stage.
  static const List<double> stageThresholds = [0.0, 0.18, 0.4, 0.65, 0.85];

  static RelationshipStage stageForCloseness(double closeness) {
    var stage = RelationshipStage.newStage;
    for (var i = 0; i < stageThresholds.length; i++) {
      if (closeness >= stageThresholds[i]) stage = RelationshipStage.values[i];
    }
    return stage;
  }

  RelationshipSummary get summary => RelationshipSummary(
    stage: stage,
    label: stageLabel(stage),
    history: List.unmodifiable(history),
    evolutionEnabled: evolutionEnabled,
  );

  /// The stage in words, for the author.
  static String stageLabel(RelationshipStage stage) => switch (stage) {
    RelationshipStage.newStage => 'New',
    RelationshipStage.familiar => 'Familiar',
    RelationshipStage.trusted => 'Trusted',
    RelationshipStage.connected => 'Connected',
    RelationshipStage.deeplyConnected => 'Deeply connected',
  };

  AuthorCharacterRelationship copyWith({
    Map<RelationshipDimension, double>? scores,
    int? sharedTurns,
    int? sharedSessions,
    List<RelationshipChange>? history,
    bool? evolutionEnabled,
  }) => AuthorCharacterRelationship(
    projectId: projectId,
    characterId: characterId,
    scores: scores ?? _scores,
    sharedTurns: sharedTurns ?? this.sharedTurns,
    sharedSessions: sharedSessions ?? this.sharedSessions,
    history: history ?? this.history,
    evolutionEnabled: evolutionEnabled ?? this.evolutionEnabled,
  );

  /// The relationship begun again, with safe defaults (plan 3.8). The author's
  /// choice about whether it may evolve is kept, and so is the history of what
  /// there was, with a line saying it was reset.
  AuthorCharacterRelationship reset({required DateTime at}) {
    final before = stage;
    return AuthorCharacterRelationship(
      projectId: projectId,
      characterId: characterId,
      evolutionEnabled: evolutionEnabled,
      history: [
        ...history,
        if (before != RelationshipStage.newStage)
          RelationshipChange(
            at: at,
            from: before,
            to: RelationshipStage.newStage,
            reason: 'The author reset the relationship.',
          ),
      ],
    );
  }

  /// A deleted conversation no longer anchors a change (plan 3.8: *deleting a
  /// conversation updates dependent relationship references appropriately*). The
  /// change itself stays, because the relationship did grow.
  AuthorCharacterRelationship removeReferencesToSession(String sessionId) =>
      copyWith(
        history: [
          for (final change in history)
            change.sessionId == sessionId ? change.withoutSource() : change,
        ],
      );

  Map<String, Object?> toJson() => {
    'schemaVersion': kRelationshipSchemaVersion,
    'projectId': projectId,
    'characterId': characterId,
    'scores': {for (final e in _scores.entries) e.key.name: e.value},
    'sharedTurns': sharedTurns,
    'sharedSessions': sharedSessions,
    'history': [for (final c in history) c.toJson()],
    'evolutionEnabled': evolutionEnabled,
  };

  /// Reads a stored relationship, or null when it names no project or character.
  /// A missing or unreadable part reads as a fresh relationship's value.
  static AuthorCharacterRelationship? fromJson(Object? json) {
    if (json is! Map) return null;
    final projectId = json['projectId'];
    final characterId = json['characterId'];
    if (projectId is! String || characterId is! String) return null;
    final raw = json['scores'];
    final scores = <RelationshipDimension, double>{};
    if (raw is Map) {
      for (final d in RelationshipDimension.values) {
        final v = raw[d.name];
        if (v is num) scores[d] = v.toDouble();
      }
    }
    final history = json['history'];
    return AuthorCharacterRelationship(
      projectId: projectId,
      characterId: characterId,
      scores: scores,
      sharedTurns: json['sharedTurns'] is int ? json['sharedTurns'] as int : 0,
      sharedSessions: json['sharedSessions'] is int
          ? json['sharedSessions'] as int
          : 0,
      history: history is List
          ? [for (final e in history) ?RelationshipChange.fromJson(e)]
          : const [],
      evolutionEnabled: json['evolutionEnabled'] != false,
    );
  }
}
