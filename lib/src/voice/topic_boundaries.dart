/// What a character is willing to talk about, and with whom.
///
/// The plan (3.5) gives five levels of topic access: Surface, Personal,
/// Sensitive, Deep and Protected, ties secrets, trauma, fears and protected
/// information to them, and lets the relationship decide how willing the
/// character is. The author can edit every one of those.
///
/// ## A boundary is a manner of speaking, not a lock
///
/// The plan states the rule twice and it is the one thing in this file that must
/// not bend: *never use boundaries to hide project data from its author;
/// boundaries are a conversational behaviour layer*, and *protected canon must
/// not be invented merely to create mystery.* So this file never sees a record. A
/// boundary is a topic key, a [TopicAccess] and a verdict on how willing the
/// character is; the verdict becomes a behaviour (deflect, redirect, withhold,
/// refuse) with a doorway to something the character *will* discuss. The author's
/// records, the Character Profile and every page that shows them are untouched,
/// and the author can always insist.
library;

import '../questions/character_question.dart';
import '../questions/question_depth.dart';
import '../questions/relationship_stage.dart';

/// How guarded a topic is.
enum TopicAccess {
  surface,
  personal,
  sensitive,
  deep,
  protectedTopic;

  /// The least well the two must know each other for the character to raise or
  /// discuss it unprompted.
  RelationshipStage get requiredStage => switch (this) {
    TopicAccess.surface || TopicAccess.personal => RelationshipStage.newStage,
    TopicAccess.sensitive => RelationshipStage.familiar,
    TopicAccess.deep => RelationshipStage.trusted,
    TopicAccess.protectedTopic => RelationshipStage.connected,
  };

  /// The deepest access a relationship at [stage] will entertain.
  static TopicAccess deepestFor(RelationshipStage stage) {
    var deepest = TopicAccess.surface;
    for (final access in TopicAccess.values) {
      if (stage.index >= access.requiredStage.index) deepest = access;
    }
    return deepest;
  }
}

/// How willing the character is, for one topic at one stage.
class BoundaryDecision {
  const BoundaryDecision({
    required this.access,
    required this.stage,
    required this.willing,
    required this.reluctant,
    required this.shortfall,
    required this.willingUpTo,
  });

  final TopicAccess access;
  final RelationshipStage stage;

  /// The character will take the topic up.
  final bool willing;

  /// The author insisted, and the character will, but not gladly.
  final bool reluctant;

  /// How many stages short of the topic the relationship is. Zero when willing.
  final int shortfall;

  /// The deepest topic the character *will* discuss now: the doorway to offer
  /// when this one is closed. A refusal that offers nothing is a dead end, and the
  /// plan asks that it never be (3.4).
  final TopicAccess willingUpTo;
}

/// The topics a character guards, as the author has set them.
class CharacterBoundaries {
  const CharacterBoundaries({
    this.byIntent = const {},
    this.byCategory = const {},
  });

  /// Overrides for a single question intent, which win over everything.
  final Map<String, TopicAccess> byIntent;

  /// Overrides for a whole category.
  final Map<QuestionCategory, TopicAccess> byCategory;

  /// How guarded a question is for this character.
  TopicAccess accessFor(CharacterQuestion question) =>
      byIntent[question.intent] ??
      byCategory[question.category] ??
      defaultAccess(question.category, question.depth);

  /// The access a category and depth carry when the author has said nothing.
  ///
  /// The deeper of two readings: what kind of thing it is (a secret is protected,
  /// a daily habit is surface) and how deep it goes (the ladder's rungs).
  static TopicAccess defaultAccess(
    QuestionCategory category,
    QuestionDepth depth,
  ) {
    final byKind = switch (category) {
      QuestionCategory.dailyLife => TopicAccess.surface,
      QuestionCategory.personality ||
      QuestionCategory.goals ||
      QuestionCategory.hypotheticals ||
      QuestionCategory.worldAndEnvironment ||
      QuestionCategory.relationships => TopicAccess.personal,
      QuestionCategory.conflict ||
      QuestionCategory.characterArc ||
      QuestionCategory.resolution ||
      QuestionCategory.fears ||
      QuestionCategory.moralChoices => TopicAccess.sensitive,
      QuestionCategory.traumaAndHistory ||
      QuestionCategory.mystery => TopicAccess.deep,
      QuestionCategory.secrets => TopicAccess.protectedTopic,
    };
    final byDepth = switch (depth) {
      QuestionDepth.surface => TopicAccess.surface,
      QuestionDepth.personal => TopicAccess.personal,
      QuestionDepth.emotional => TopicAccess.sensitive,
      QuestionDepth.psychological ||
      QuestionDepth.storyCritical => TopicAccess.deep,
    };
    return byKind.index >= byDepth.index ? byKind : byDepth;
  }

  CharacterBoundaries withIntent(String intent, TopicAccess access) =>
      CharacterBoundaries(
        byIntent: {...byIntent, intent: access},
        byCategory: byCategory,
      );

  CharacterBoundaries withCategory(
    QuestionCategory category,
    TopicAccess access,
  ) => CharacterBoundaries(
    byIntent: byIntent,
    byCategory: {...byCategory, category: access},
  );

  /// The author's override removed, so the default applies again.
  CharacterBoundaries withoutIntent(String intent) => CharacterBoundaries(
    byIntent: {...byIntent}..remove(intent),
    byCategory: byCategory,
  );

  CharacterBoundaries withoutCategory(QuestionCategory category) =>
      CharacterBoundaries(
        byIntent: byIntent,
        byCategory: {...byCategory}..remove(category),
      );

  /// How willing a character at [stage] is to discuss something guarded at
  /// [access]. When [authorInsists], the character will, with reluctance if the
  /// relationship has not earned it: the author is the authority on their own
  /// story.
  static BoundaryDecision decide(
    TopicAccess access,
    RelationshipStage stage, {
    bool authorInsists = false,
  }) {
    final shortfall = (access.requiredStage.index - stage.index).clamp(0, 99);
    final willing = shortfall == 0;
    return BoundaryDecision(
      access: access,
      stage: stage,
      willing: willing || authorInsists,
      reluctant: !willing && authorInsists,
      shortfall: shortfall,
      willingUpTo: TopicAccess.deepestFor(stage),
    );
  }

  Map<String, Object?> toJson() => {
    'byIntent': {for (final e in byIntent.entries) e.key: e.value.name},
    'byCategory': {
      for (final e in byCategory.entries) e.key.name: e.value.name,
    },
  };

  static CharacterBoundaries fromJson(Object? json) {
    if (json is! Map) return const CharacterBoundaries();
    TopicAccess? access(Object? raw) {
      for (final a in TopicAccess.values) {
        if (a.name == raw) return a;
      }
      return null;
    }

    final intents = <String, TopicAccess>{};
    final rawIntents = json['byIntent'];
    if (rawIntents is Map) {
      for (final e in rawIntents.entries) {
        final a = access(e.value);
        if (e.key is String && a != null) intents[e.key as String] = a;
      }
    }
    final categories = <QuestionCategory, TopicAccess>{};
    final rawCategories = json['byCategory'];
    if (rawCategories is Map) {
      for (final category in QuestionCategory.values) {
        final a = access(rawCategories[category.name]);
        if (a != null) categories[category] = a;
      }
    }
    return CharacterBoundaries(byIntent: intents, byCategory: categories);
  }
}
