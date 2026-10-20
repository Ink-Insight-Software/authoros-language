/// How a character speaks: their voice, apart from who they are to the author.
///
/// Phase 3 of the master build plan opens with one distinction (3.1): *personality
/// determines how the character speaks; relationship determines how the character
/// speaks specifically to the author.* This file is the first half. A
/// [VoiceProfile] is the stable part: tone, energy, humour, openness, confidence,
/// how much they say, how guarded they are, how warm, how willing to push back,
/// their vocabulary and rhythm. It changes when the author edits it and at no
/// other time. What changes with the conversation is [AuthorCharacterRelationship]
/// and the passing mood, which live elsewhere.
///
/// ## A voice holds style and never fact
///
/// The plan is explicit (3.2): *voice attributes must not override explicit canon.*
/// The simplest way to make that true is that a profile has nowhere to put a fact.
/// Every field here is a way of speaking, and a test holds the list of fields so a
/// fact cannot be added by accident. What a character *knows* stays in the
/// project's records, where the engine reads it.
///
/// ## Defaults, and what is missing
///
/// A new or sparsely written character has no voice yet, and the plan asks that
/// this be safe (3.1: *allow voice defaults when character data is incomplete*).
/// [VoiceProfile.defaults] is the neutral voice: everything in the middle. A
/// stored profile with a field missing, or holding a value this version does not
/// know, reads as that field's default, so a profile written by a newer version
/// still opens (the readable-window rule the expansion manifests use).
library;

/// A five-step scale for the attributes the author sets by feel.
enum VoiceLevel {
  veryLow,
  low,
  medium,
  high,
  veryHigh;

  /// The level as a number from zero to one, for composing a delivery style.
  double get value => index / (VoiceLevel.values.length - 1);

  /// The level nearest [value], which is clamped to zero to one.
  static VoiceLevel fromValue(double value) {
    final steps = VoiceLevel.values.length - 1;
    return VoiceLevel.values[(value.clamp(0.0, 1.0) * steps).round()];
  }
}

/// The overall colour of how they speak.
enum VoiceTone {
  neutral,
  warm,
  gentle,
  earnest,
  dry,
  sardonic,
  blunt,
  formal,
  timid,
  quiet,
  playful,
  stoic,
}

/// How much they say.
enum CommunicationLength { terse, measured, expansive }

/// The kind of words they reach for.
enum VocabularyRegister { plain, educated, earthy, archaic, technical }

/// The pace and shape of their sentences.
enum ConversationalRhythm { even, clipped, flowing, halting }

/// How formal a character's questions sound when the guided exercise is asked in
/// their voice. A way of speaking only: it says nothing about intelligence,
/// morality or class (Phase 4).
enum QuestionRegister { neutral, formal, casual }

/// Whether a question is asked briefly or with a slightly fuller authored line.
enum QuestionPhrasing { concise, reflective }

/// Whether a question is asked directly, or with a gentle authored lead-in. A
/// reserved delivery never asserts a hidden feeling.
enum QuestionDelivery { direct, reserved }

/// The version of the stored shape. Version 2 adds the guided-question voice
/// settings; a version 1 profile reads them as the neutral defaults.
const int kVoiceProfileSchemaVersion = 2;

/// The stable way one character speaks.
class VoiceProfile {
  const VoiceProfile({
    required this.projectId,
    required this.characterId,
    this.tone = VoiceTone.neutral,
    this.energy = VoiceLevel.medium,
    this.humour = VoiceLevel.medium,
    this.openness = VoiceLevel.medium,
    this.confidence = VoiceLevel.medium,
    this.communicationLength = CommunicationLength.measured,
    this.defensiveness = VoiceLevel.medium,
    this.affection = VoiceLevel.medium,
    this.challengeLevel = VoiceLevel.medium,
    this.vocabulary = VocabularyRegister.plain,
    this.rhythm = ConversationalRhythm.even,
    this.speechPatterns = const [],
    this.voiceNotes = '',
    this.examples = const [],
    this.questionRegister = QuestionRegister.neutral,
    this.questionPhrasing = QuestionPhrasing.concise,
    this.questionDelivery = QuestionDelivery.direct,
    this.address = '',
    this.signature = '',
    this.guidedRevision = 0,
  });

  /// The neutral voice, for a character who has none yet.
  const VoiceProfile.defaults({
    required String projectId,
    required String characterId,
  }) : this(projectId: projectId, characterId: characterId);

  /// Voice data belongs to one project (plan 3.1).
  final String projectId;
  final String characterId;

  final VoiceTone tone;
  final VoiceLevel energy;
  final VoiceLevel humour;

  /// How willing they are to talk about themselves.
  final VoiceLevel openness;
  final VoiceLevel confidence;
  final CommunicationLength communicationLength;

  /// How readily they close up when pressed.
  final VoiceLevel defensiveness;
  final VoiceLevel affection;

  /// How readily they push back.
  final VoiceLevel challengeLevel;
  final VocabularyRegister vocabulary;
  final ConversationalRhythm rhythm;

  /// Habits of speech the author wants kept. Not catchphrases to repeat every
  /// turn: the composer will not use one on consecutive turns (plan 3.2).
  final List<String> speechPatterns;

  /// Free guidance in the author's own words, beside the structured attributes.
  final String voiceNotes;

  /// Lines the author wrote to show the voice.
  final List<String> examples;

  /// How the guided exercise sounds when this character is the speaker. The
  /// author chooses these; nothing infers them from a personality, prose or a
  /// relationship.
  final QuestionRegister questionRegister;
  final QuestionPhrasing questionPhrasing;
  final QuestionDelivery questionDelivery;

  /// An optional form of address, used only in lines that declare an address
  /// slot. Inserted literally.
  final String address;

  /// An optional short phrase the author wrote, used only in lines that declare a
  /// signature slot, at most once in five character questions. Inserted literally.
  final String signature;

  /// Counts the saves of the guided-question settings, so a saved question can
  /// say which version of the voice it was asked in.
  final int guidedRevision;

  /// Whether the guided-question settings are all at their neutral defaults.
  bool get guidedIsDefault =>
      questionRegister == QuestionRegister.neutral &&
      questionPhrasing == QuestionPhrasing.concise &&
      questionDelivery == QuestionDelivery.direct &&
      address.trim().isEmpty &&
      signature.trim().isEmpty;

  /// Whether nothing has been set beyond the neutral voice.
  bool get isDefault => _sameStyle(
    this,
    VoiceProfile.defaults(projectId: projectId, characterId: characterId),
  );

  VoiceProfile copyWith({
    VoiceTone? tone,
    VoiceLevel? energy,
    VoiceLevel? humour,
    VoiceLevel? openness,
    VoiceLevel? confidence,
    CommunicationLength? communicationLength,
    VoiceLevel? defensiveness,
    VoiceLevel? affection,
    VoiceLevel? challengeLevel,
    VocabularyRegister? vocabulary,
    ConversationalRhythm? rhythm,
    List<String>? speechPatterns,
    String? voiceNotes,
    List<String>? examples,
    QuestionRegister? questionRegister,
    QuestionPhrasing? questionPhrasing,
    QuestionDelivery? questionDelivery,
    String? address,
    String? signature,
    int? guidedRevision,
  }) => VoiceProfile(
    projectId: projectId,
    characterId: characterId,
    tone: tone ?? this.tone,
    energy: energy ?? this.energy,
    humour: humour ?? this.humour,
    openness: openness ?? this.openness,
    confidence: confidence ?? this.confidence,
    communicationLength: communicationLength ?? this.communicationLength,
    defensiveness: defensiveness ?? this.defensiveness,
    affection: affection ?? this.affection,
    challengeLevel: challengeLevel ?? this.challengeLevel,
    vocabulary: vocabulary ?? this.vocabulary,
    rhythm: rhythm ?? this.rhythm,
    speechPatterns: speechPatterns ?? this.speechPatterns,
    voiceNotes: voiceNotes ?? this.voiceNotes,
    examples: examples ?? this.examples,
    questionRegister: questionRegister ?? this.questionRegister,
    questionPhrasing: questionPhrasing ?? this.questionPhrasing,
    questionDelivery: questionDelivery ?? this.questionDelivery,
    address: address ?? this.address,
    signature: signature ?? this.signature,
    guidedRevision: guidedRevision ?? this.guidedRevision,
  );

  /// The fields a profile stores, in order. A test holds this list, so a field
  /// that is a fact rather than a way of speaking cannot be added quietly.
  static const List<String> storedFields = [
    'schemaVersion',
    'projectId',
    'characterId',
    'tone',
    'energy',
    'humour',
    'openness',
    'confidence',
    'communicationLength',
    'defensiveness',
    'affection',
    'challengeLevel',
    'vocabulary',
    'rhythm',
    'speechPatterns',
    'voiceNotes',
    'examples',
    'questionRegister',
    'questionPhrasing',
    'questionDelivery',
    'address',
    'signature',
    'guidedRevision',
  ];

  Map<String, Object?> toJson() => {
    'schemaVersion': kVoiceProfileSchemaVersion,
    'projectId': projectId,
    'characterId': characterId,
    'tone': tone.name,
    'energy': energy.name,
    'humour': humour.name,
    'openness': openness.name,
    'confidence': confidence.name,
    'communicationLength': communicationLength.name,
    'defensiveness': defensiveness.name,
    'affection': affection.name,
    'challengeLevel': challengeLevel.name,
    'vocabulary': vocabulary.name,
    'rhythm': rhythm.name,
    'speechPatterns': speechPatterns,
    'voiceNotes': voiceNotes,
    'examples': examples,
    'questionRegister': questionRegister.name,
    'questionPhrasing': questionPhrasing.name,
    'questionDelivery': questionDelivery.name,
    'address': address,
    'signature': signature,
    'guidedRevision': guidedRevision,
  };

  /// Reads a stored profile, or null when it names no project or character.
  ///
  /// Never throws on the rest: a missing field or a value this version does not
  /// know reads as the default, and a profile from a newer version keeps what
  /// this one understands.
  static VoiceProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    final projectId = json['projectId'];
    final characterId = json['characterId'];
    if (projectId is! String || characterId is! String) return null;
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
      for (final value in values) {
        if (value.name == raw) return value;
      }
      return fallback;
    }

    List<String> strings(Object? raw) => raw is List
        ? [
            for (final e in raw)
              if (e is String) e,
          ]
        : const [];

    const base = VoiceProfile.defaults(projectId: '', characterId: '');
    return VoiceProfile(
      projectId: projectId,
      characterId: characterId,
      tone: pick(VoiceTone.values, json['tone'], base.tone),
      energy: pick(VoiceLevel.values, json['energy'], base.energy),
      humour: pick(VoiceLevel.values, json['humour'], base.humour),
      openness: pick(VoiceLevel.values, json['openness'], base.openness),
      confidence: pick(VoiceLevel.values, json['confidence'], base.confidence),
      communicationLength: pick(
        CommunicationLength.values,
        json['communicationLength'],
        base.communicationLength,
      ),
      defensiveness: pick(
        VoiceLevel.values,
        json['defensiveness'],
        base.defensiveness,
      ),
      affection: pick(VoiceLevel.values, json['affection'], base.affection),
      challengeLevel: pick(
        VoiceLevel.values,
        json['challengeLevel'],
        base.challengeLevel,
      ),
      vocabulary: pick(
        VocabularyRegister.values,
        json['vocabulary'],
        base.vocabulary,
      ),
      rhythm: pick(ConversationalRhythm.values, json['rhythm'], base.rhythm),
      speechPatterns: strings(json['speechPatterns']),
      voiceNotes: json['voiceNotes'] is String
          ? json['voiceNotes'] as String
          : '',
      examples: strings(json['examples']),
      questionRegister: pick(
        QuestionRegister.values,
        json['questionRegister'],
        base.questionRegister,
      ),
      questionPhrasing: pick(
        QuestionPhrasing.values,
        json['questionPhrasing'],
        base.questionPhrasing,
      ),
      questionDelivery: pick(
        QuestionDelivery.values,
        json['questionDelivery'],
        base.questionDelivery,
      ),
      address: json['address'] is String ? json['address'] as String : '',
      signature: json['signature'] is String ? json['signature'] as String : '',
      guidedRevision: json['guidedRevision'] is int
          ? json['guidedRevision'] as int
          : 0,
    );
  }

  static bool _sameStyle(VoiceProfile a, VoiceProfile b) =>
      a.tone == b.tone &&
      a.energy == b.energy &&
      a.humour == b.humour &&
      a.openness == b.openness &&
      a.confidence == b.confidence &&
      a.communicationLength == b.communicationLength &&
      a.defensiveness == b.defensiveness &&
      a.affection == b.affection &&
      a.challengeLevel == b.challengeLevel &&
      a.vocabulary == b.vocabulary &&
      a.rhythm == b.rhythm &&
      a.speechPatterns.isEmpty &&
      a.voiceNotes.isEmpty &&
      a.examples.isEmpty &&
      a.guidedIsDefault;
}
