/// How deep a question goes, and how deep a conversation has got.
///
/// The five levels are `ChatTopic.depth` in `authoros_core`, one to five, which
/// that library took from Altman and Taylor's social-penetration ladder:
/// favourite food is one, the core wound is five. The master build plan (2.6)
/// names them Surface, Personal, Emotional, Psychological and Story-Critical, and
/// asks that depth be *earned*, so this enum is the plan's names over the core's
/// numbers and the two never disagree.
library;

/// The five rungs of the ladder.
enum QuestionDepth {
  /// Light, daily-life and preference questions.
  surface,

  /// Memories, beliefs, goals and relationships.
  personal,

  /// Fears, regrets, attachment, shame and vulnerability.
  emotional,

  /// Contradictions, false beliefs, self-image and internal conflict.
  psychological,

  /// Sacrifices, moral breaking points, arc-defining decisions and endgame
  /// motivations.
  storyCritical;

  /// The rung, one to five: `ChatTopic.depth` in `authoros_core`.
  int get rung => index + 1;

  /// The level for a core rung. Anything outside one to five is clamped, so a
  /// stored value from a newer ladder degrades rather than throws.
  static QuestionDepth fromRung(int rung) =>
      values[rung.clamp(1, values.length) - 1];

  /// One rung deeper, or this one at the bottom of the well.
  QuestionDepth get deeper => fromRung(rung + 1);

  /// One rung lighter, or this one at the surface.
  QuestionDepth get lighter => fromRung(rung - 1);
}
