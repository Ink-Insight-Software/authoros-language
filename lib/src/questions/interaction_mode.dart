/// The ways of being with a character (the Companion plan, "Creative modes").
///
/// Talk is the centre. Every other mode is Talk with different rules about which
/// questions come up, how deep they go, how long the character speaks and whether
/// what is said can be noticed as a discovery. A mode is therefore data: a
/// [ModeProfile] the question selector and the turn pipeline read. Nothing here
/// speaks, and nothing changes the author's project.
library;

import 'character_question.dart';
import 'question_depth.dart';

enum InteractionMode {
  talk,
  unblock,
  discover,
  rapidFire,
  stressTest,
  rehearse,
  campfire,
  explore;

  ModeProfile get profile => ModeProfile.of(this);
}

/// What a mode asks of the question selector and the pipeline.
class ModeProfile {
  const ModeProfile({
    required this.label,
    required this.tagline,
    this.categories = const {},
    this.methods = const {},
    this.depthCap,
    this.depthLean = 0,
    this.detectsDiscoveries = true,
    this.brief = false,
  });

  final String label;

  /// One line saying what the mode is for, in the author's words.
  final String tagline;

  /// The question categories this mode draws on; empty means any.
  final Set<QuestionCategory> categories;

  /// The methods this mode prefers to ask in. A preference, never a rule.
  final Set<QuestionMethod> methods;

  /// The deepest this mode goes, whatever the relationship would allow. Null
  /// leaves the relationship's own ceiling.
  final QuestionDepth? depthCap;

  /// Added to a question's score for each rung of depth above the middle: positive
  /// leans deeper, negative lighter.
  final double depthLean;

  /// Whether what the author says can be noticed as a discovery. Off for
  /// Campfire, which is allowed to accomplish nothing, and Rehearse, whose
  /// words are not the story.
  final bool detectsDiscoveries;

  /// Short turns: no preamble, one thing at a time.
  final bool brief;

  bool accepts(QuestionCategory category) =>
      categories.isEmpty || categories.contains(category);

  /// The mode actually in force. Unblock quietly changes approach when direct
  /// questioning is not working: after repeated "I don't know" it walks the
  /// author through the place and the memory instead of asking again.
  InteractionMode effective(InteractionMode mode, int uncertainStreak) =>
      mode == InteractionMode.unblock && uncertainStreak >= 2
      ? InteractionMode.explore
      : mode;

  static ModeProfile of(InteractionMode mode) => _profiles[mode]!;

  static const _profiles = <InteractionMode, ModeProfile>{
    InteractionMode.talk: ModeProfile(
      label: 'Talk',
      tagline: 'Natural conversation',
    ),
    InteractionMode.unblock: ModeProfile(
      label: 'Unblock',
      tagline: "Work through what's stuck",
      categories: {
        QuestionCategory.conflict,
        QuestionCategory.goals,
        QuestionCategory.relationships,
        QuestionCategory.characterArc,
        QuestionCategory.mystery,
        QuestionCategory.resolution,
        QuestionCategory.moralChoices,
        QuestionCategory.fears,
      },
      methods: {
        QuestionMethod.scenario,
        QuestionMethod.hypothetical,
        QuestionMethod.otherCharacter,
      },
      depthCap: QuestionDepth.emotional,
    ),
    InteractionMode.discover: ModeProfile(
      label: 'Discover',
      tagline: 'Ask deeper questions',
      categories: {
        QuestionCategory.personality,
        QuestionCategory.fears,
        QuestionCategory.goals,
        QuestionCategory.traumaAndHistory,
        QuestionCategory.secrets,
        QuestionCategory.characterArc,
        QuestionCategory.mystery,
        QuestionCategory.moralChoices,
      },
      depthLean: 0.3,
    ),
    InteractionMode.rapidFire: ModeProfile(
      label: 'Rapid Fire',
      tagline: 'Quickfire prompts',
      categories: {
        QuestionCategory.dailyLife,
        QuestionCategory.personality,
        QuestionCategory.hypotheticals,
        QuestionCategory.relationships,
        QuestionCategory.moralChoices,
        QuestionCategory.goals,
      },
      methods: {QuestionMethod.hypothetical, QuestionMethod.direct},
      depthCap: QuestionDepth.personal,
      depthLean: -0.2,
      brief: true,
    ),
    InteractionMode.stressTest: ModeProfile(
      label: 'Stress Test',
      tagline: 'Challenge their ideas',
      categories: {
        QuestionCategory.conflict,
        QuestionCategory.moralChoices,
        QuestionCategory.hypotheticals,
        QuestionCategory.secrets,
        QuestionCategory.relationships,
        QuestionCategory.fears,
        QuestionCategory.resolution,
      },
      methods: {QuestionMethod.hypothetical, QuestionMethod.scenario},
      depthLean: 0.4,
    ),
    InteractionMode.rehearse: ModeProfile(
      label: 'Rehearse',
      tagline: 'Try scenes and dialogue',
      detectsDiscoveries: false,
    ),
    InteractionMode.campfire: ModeProfile(
      label: 'Campfire',
      tagline: 'Casual, in-character chat',
      categories: {
        QuestionCategory.dailyLife,
        QuestionCategory.personality,
        QuestionCategory.relationships,
        QuestionCategory.worldAndEnvironment,
        QuestionCategory.hypotheticals,
      },
      methods: {QuestionMethod.memory, QuestionMethod.sensory},
      depthCap: QuestionDepth.personal,
      depthLean: -0.3,
      detectsDiscoveries: false,
    ),
    InteractionMode.explore: ModeProfile(
      label: 'Explore',
      tagline: 'Character-led deep dive',
      categories: {
        QuestionCategory.worldAndEnvironment,
        QuestionCategory.traumaAndHistory,
        QuestionCategory.dailyLife,
        QuestionCategory.mystery,
      },
      methods: {
        QuestionMethod.location,
        QuestionMethod.sensory,
        QuestionMethod.memory,
      },
      depthCap: QuestionDepth.emotional,
    ),
  };
}
