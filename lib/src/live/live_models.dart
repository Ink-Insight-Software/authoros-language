/// What a live conversation turn is made of: who is speaking, what they know, what the
/// engine decided they should do, and what was said so far.
///
/// The engine decides *what* the character does (ask this question, answer from these
/// facts, close the thread, hold something back). A model decides only *how it sounds*,
/// inside those decisions and inside what the character knows. Nothing here asks a model
/// to choose a question or to make up the story.
library;

import '../language/character_answerer.dart' show KnownFact;
import '../questions/relationship_stage.dart';
import 'live_feedback.dart';
import '../voice/relationship_behaviour.dart'
    show EmotionalState, RelationshipBehaviour;
import '../voice/voice_profile.dart';

enum LiveSpeaker { author, character }

class LiveLine {
  const LiveLine(this.speaker, this.text);
  final LiveSpeaker speaker;
  final String text;
}

/// Whether what is said counts as canon. Nothing said in either is canon until the
/// author confirms it; "what if" invites the character to speculate, and says so.
enum LiveMode { canon, hypothetical }

/// What the engine decided for this turn.
class LiveDirective {
  const LiveDirective({
    required this.behaviour,
    this.question,
    this.draft = const [],
    this.authorAsked = false,
    this.opening = false,
  });

  /// How the character is being with the author just now (open, teasing, guarded...).
  final RelationshipBehaviour behaviour;

  /// What the engine chose to find out next. The character asks it in their own words
  /// as the one question that ends the reply, or, if it is already answered or
  /// repeated, the natural next one.
  final String? question;

  /// What the rule-based engine would say this turn, in plain words. It carries the
  /// engine's decisions (what to hold back, what the character knows). The model puts
  /// the same things in the character's own voice; it does not add to them.
  final List<String> draft;

  /// The author put a question to the character.
  final bool authorAsked;

  /// The character speaks first.
  final bool opening;

  /// The character closes the thread rather than asking on.
  bool get closes => question == null && behaviour.closes;
}

/// Something the character knows, believes or suspects about the story, with the
/// sentence of the author's text it comes from.
class StoryFact {
  const StoryFact({required this.text, required this.state, this.source});

  /// The author's own sentence.
  final String text;

  /// `knows`, `believes`, `suspects` or `misremembers`.
  final String state;

  /// Which passage it is from, for provenance.
  final String? source;
}

class LiveTurnInput {
  const LiveTurnInput({
    required this.characterName,
    required this.directive,
    this.pronouns,
    this.roles,
    this.epithet,
    this.summary,
    this.traits = const [],
    this.speechStyle,
    this.tone = VoiceTone.neutral,
    this.length = CommunicationLength.measured,
    this.stage = RelationshipStage.newStage,
    this.mood = EmotionalState.calm,
    this.facts = const [],
    this.storyFacts = const [],
    this.mode = LiveMode.canon,
    this.history = const [],
    this.authorText,
    this.sceneTitle,
    this.authorName,
    this.guidance = FeedbackGuidance.none,
  });

  final String characterName;

  /// What the engine decided for this turn.
  final LiveDirective directive;
  final String? pronouns;
  final String? roles;
  final String? epithet;
  final String? summary;
  final List<String> traits;
  final String? speechStyle;
  final VoiceTone tone;
  final CommunicationLength length;
  final RelationshipStage stage;
  final EmotionalState mood;

  /// What the author wrote about the character (identity, traits, fear, want).
  final List<KnownFact> facts;

  /// What the character knows of events in the story, at this point in it.
  final List<StoryFact> storyFacts;
  final LiveMode mode;

  /// The conversation so far, oldest first, ending before the author's new line.
  final List<LiveLine> history;

  /// What the author just said. Null when the character speaks first or the author only
  /// nudged the conversation along.
  final String? authorText;
  final String? sceneTitle;
  final String? authorName;

  /// What the author has told this character about how they answer. About manner only,
  /// never facts.
  final FeedbackGuidance guidance;

  /// Tender facts open up once the character knows the author a little, the same
  /// boundary the rule-based answerer keeps.
  List<KnownFact> get usableFacts => [
    for (final f in facts)
      if (!f.tender || stage.index >= RelationshipStage.familiar.index) f,
  ];

  LiveTurnInput copyWith({List<LiveLine>? history}) => LiveTurnInput(
    characterName: characterName,
    directive: directive,
    pronouns: pronouns,
    roles: roles,
    epithet: epithet,
    summary: summary,
    traits: traits,
    speechStyle: speechStyle,
    tone: tone,
    length: length,
    stage: stage,
    mood: mood,
    facts: facts,
    storyFacts: storyFacts,
    mode: mode,
    history: history ?? this.history,
    authorText: authorText,
    sceneTitle: sceneTitle,
    authorName: authorName,
    guidance: guidance,
  );
}

/// What a live turn produced.
class LiveReply {
  const LiveReply({
    required this.text,
    required this.live,
    this.introduced = const [],
    this.fallbackReason,
    this.attempts = 0,
    this.problems = const [],
  });

  /// What the character says.
  final String text;

  /// The model wrote it and it passed every check. False: the engine's own wording.
  final bool live;

  /// Story details the character brought in that the story does not hold. Only ever
  /// non-empty in a "what if" conversation; in canon the reply is refused instead.
  final List<String> introduced;

  /// Why the engine's wording was used, when a model was expected.
  final String? fallbackReason;
  final int attempts;

  /// What the checks found wrong on the last attempt, for a developer.
  final List<String> problems;
}
