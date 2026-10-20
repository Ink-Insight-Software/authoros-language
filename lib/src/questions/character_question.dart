/// A question the character can ask the author.
///
/// The master build plan (2.1) defines the model and one design rule: *the
/// question library is not the conversation engine. The library provides
/// possible doors; the engine decides which door should open now.* So this is
/// data only. Nothing here chooses, ranks or says anything.
///
/// ## What a question is, and what it is not
///
/// [text] is the neutral phrasing, in the character's first person. It is the
/// *meaning* of the question, not the final wording: delivery (plan 2.3) is a
/// separate layer and may say it differently for a sarcastic character and a
/// reserved one. [intent] is the stable key for what is being asked, shared by
/// every wording of it, and is what repetition is measured on: "Why did you make
/// me forgive him?" asked two ways is one intent asked twice.
///
/// ## Slots
///
/// A [text] may hold `{other}` or `{place}`. They are filled from the context
/// (`QuestionContext.slots`) with names the author already wrote, never with
/// anything the engine made up. A question whose slot cannot be filled is not
/// eligible, which is what keeps "Why does {other} matter so much to me?" from
/// ever reaching the author unfilled.
library;

import 'interaction_mode.dart';
import 'question_depth.dart';
import 'relationship_stage.dart';

/// The fourteen core categories (plan 2.1).
enum QuestionCategory {
  conflict,
  relationships,
  personality,
  characterArc,
  secrets,
  fears,
  goals,
  traumaAndHistory,
  hypotheticals,
  dailyLife,
  worldAndEnvironment,
  moralChoices,
  mystery,
  resolution,
}

/// How a question gets at what it wants to know.
///
/// When an author says "I don't know", the engine changes *method* rather than
/// rephrasing the same question (plan 2.2, 2.9). These are the alternatives the
/// plan names: a concrete scenario, a memory, a place, a hypothetical, another
/// character, a sensory prompt.
enum QuestionMethod {
  /// Asked head on.
  direct,

  /// "Walk me through the last time..."
  scenario,

  /// "Tell me about a time..."
  memory,

  /// Anchored in a place.
  location,

  /// "If I could..."
  hypothetical,

  /// Seen through another character.
  otherCharacter,

  /// Anchored in a sense: a smell, a sound, a texture.
  sensory;

  /// Whether this is one of the concrete alternatives to asking directly.
  bool get isAlternate => this != QuestionMethod.direct;
}

/// A piece of story context a question can need or prefer.
///
/// The plan's list of what selection loads (2.2) as keys, so a question can say
/// what it needs without the engine loading the whole project to find out
/// (plan 2.4: *scope retrieval so large projects do not load everything for every
/// turn*).
enum ContextKey {
  currentScene,
  currentChapter,
  pointOfView,
  profile,
  goals,
  fears,
  beliefs,
  relationships,
  otherCharacter,
  history,
  arcPosition,
  conflict,
  recentEvents,
  plotThreads,
  location,

  /// A guided walk through a place is under way, so its next step can be asked.
  activeWalk,

  /// No walk has been taken yet this conversation, so one can begin.
  walkOpen,
  timeline,
  world,
  priorDiscoveries,
  contradictions,
  manuscriptText,
}

/// Where a question came from.
enum QuestionSource {
  /// The built-in library.
  core,

  /// A question pack, installed separately (plan 2.1: *allow future question
  /// packs without rewriting the engine*).
  pack,

  /// Written for one character by the author.
  author,
}

/// What an answer can set off, so a follow-up can be queued.
enum FollowUpTrigger {
  /// Any answer at all.
  anyAnswer,

  /// "I don't know", "maybe", "I'm not sure".
  uncertain,

  /// The answer named a person.
  namesPerson,

  /// The answer named a place.
  namesPlace,

  /// The answer named an event.
  namesEvent,

  /// The answer carried feeling.
  emotional,
}

/// "If the answer is like this, ask that next."
class FollowUpRule {
  const FollowUpRule(this.trigger, this.intent);

  final FollowUpTrigger trigger;

  /// The [CharacterQuestion.intent] to ask next.
  final String intent;
}

/// One door the character could open.
class CharacterQuestion {
  const CharacterQuestion({
    required this.id,
    required this.text,
    required this.intent,
    required this.category,
    this.depth = QuestionDepth.personal,
    this.method = QuestionMethod.direct,
    this.requiredContext = const {},
    this.preferredContext = const {},
    this.relationshipRequirement = RelationshipStage.newStage,
    this.characterSpecific,
    this.followUpRules = const [],
    this.discoveryPotential = 0.3,
    this.contradictionPotential = 0.0,
    this.priority = 0,
    this.source = QuestionSource.core,
    this.onlyIn = const {},
  }) : assert(discoveryPotential >= 0 && discoveryPotential <= 1),
       assert(contradictionPotential >= 0 && contradictionPotential <= 1);

  /// Unique within a library.
  final String id;

  /// The neutral phrasing, in the character's first person.
  final String text;

  /// What is being asked, shared by every wording of it.
  final String intent;

  final QuestionCategory category;
  final QuestionDepth depth;
  final QuestionMethod method;

  /// Context without which this question cannot be asked.
  final Set<ContextKey> requiredContext;

  /// Context that makes it better, but is not needed.
  final Set<ContextKey> preferredContext;

  /// The least well the character and author must know each other.
  final RelationshipStage relationshipRequirement;

  /// The character this is written for, or null for any.
  final String? characterSpecific;

  final List<FollowUpRule> followUpRules;

  /// How likely an answer is to surface something worth keeping, zero to one.
  final double discoveryPotential;

  /// How likely an answer is to expose a conflict with what is recorded, zero to
  /// one.
  final double contradictionPotential;

  /// A nudge between otherwise equal candidates. Never decisive.
  final int priority;

  final QuestionSource source;

  /// The modes this question belongs to. Empty means any; otherwise it is asked
  /// in these modes and nowhere else, so a quick question never answers a request
  /// to talk about the plot.
  final Set<InteractionMode> onlyIn;

  /// The slots in [text], such as `other` for `{other}`.
  Set<String> get slotKeys => {
    for (final match in _slot.allMatches(text)) match.group(1)!,
  };

  /// [text] with its slots filled, or null when one cannot be.
  String? fill(Map<String, String> slots) {
    var complete = true;
    final filled = text.replaceAllMapped(_slot, (match) {
      final value = slots[match.group(1)!];
      if (value == null || value.trim().isEmpty) {
        complete = false;
        return match.group(0)!;
      }
      return value;
    });
    return complete ? filled : null;
  }

  static final RegExp _slot = RegExp(r'\{(\w+)\}');
}
