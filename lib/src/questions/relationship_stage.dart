/// How well the character and the author know each other.
///
/// Phase 3 of the master build plan (3.3) names five internal states and says
/// they are never shown as numbers. This is the smallest part of that model the
/// question engine needs: an ordered stage, and the deepest question each stage
/// will entertain. The rest of Phase 3 (how a stage evolves from history) is not
/// here yet; until it is, a caller passes the stage it knows.
library;

import 'question_depth.dart';

/// The internal relationship states, in order.
enum RelationshipStage {
  newStage,
  familiar,
  trusted,
  connected,
  deeplyConnected;

  /// The deepest question this stage will ask unprompted.
  ///
  /// A character earns its way inward: a stranger is not asked about their core
  /// wound. The author can still raise the ceiling for a conversation
  /// (`QuestionContext.depthCeiling`), but only ever lower it from here by
  /// asking for something lighter.
  QuestionDepth get maxDepth => switch (this) {
    RelationshipStage.newStage => QuestionDepth.personal,
    RelationshipStage.familiar => QuestionDepth.emotional,
    RelationshipStage.trusted => QuestionDepth.psychological,
    RelationshipStage.connected ||
    RelationshipStage.deeplyConnected => QuestionDepth.storyCritical,
  };
}
