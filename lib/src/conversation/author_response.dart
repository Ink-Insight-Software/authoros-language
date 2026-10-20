/// What the author's answer turned out to be.
///
/// Plan 2.9 asks that natural, messy author input become useful signals *without
/// forcing the author into forms*, and that the raw words be preserved *alongside*
/// whatever is read from them. This is that structure: the author's text, kept as
/// they wrote it, and a set of things the answer was doing (uncertain, a
/// correction, a disagreement, several possibilities, a question back, a change of
/// subject, a request to stop) with the terms it turned on.
///
/// **Reading an answer is not done here.** Turning words into this structure is the
/// language layer's work (plan 2.9), behind an interface, with a rule-based reader
/// first. What lives here is the shape every reader fills in, and the questions the
/// rest of the engine asks of it: it never has to know how the answer was read.
library;

import '../json_support.dart';

/// What an answer was doing. An answer can be more than one thing.
enum ResponseIntent {
  /// A substantive answer.
  answer,

  /// "I don't know", "maybe", "I'm not sure".
  uncertain,

  /// The author is correcting something the character or the records said.
  correction,

  /// The author disagrees with the character.
  disagreement,

  /// Several possibilities offered, none chosen. Brainstorming, not canon.
  multiplePossibilities,

  /// The author asked the character something.
  questionBack,

  /// The author wants to talk about something else.
  topicChange,

  /// The author wants to leave this topic alone.
  stop,

  /// The author passes on this one for now.
  skip,
}

/// The terms an answer turned on, by kind, for follow-ups and discovery.
class ResponseTerms {
  const ResponseTerms({
    this.people = const {},
    this.places = const {},
    this.events = const {},
    this.emotions = const {},
    this.motivations = const {},
    this.values = const {},
    this.fears = const {},
  });

  final Set<String> people;
  final Set<String> places;
  final Set<String> events;
  final Set<String> emotions;
  final Set<String> motivations;
  final Set<String> values;
  final Set<String> fears;

  bool get isEmpty =>
      people.isEmpty &&
      places.isEmpty &&
      events.isEmpty &&
      emotions.isEmpty &&
      motivations.isEmpty &&
      values.isEmpty &&
      fears.isEmpty;

  /// Every term, whatever its kind.
  Set<String> get all => {
    ...people,
    ...places,
    ...events,
    ...emotions,
    ...motivations,
    ...values,
    ...fears,
  };

  Map<String, Object?> toJson() => {
    'people': people.toList()..sort(),
    'places': places.toList()..sort(),
    'events': events.toList()..sort(),
    'emotions': emotions.toList()..sort(),
    'motivations': motivations.toList()..sort(),
    'values': values.toList()..sort(),
    'fears': fears.toList()..sort(),
  };

  static ResponseTerms fromJson(Object? json) {
    if (json is! Map) return const ResponseTerms();
    return ResponseTerms(
      people: stringList(json['people']).toSet(),
      places: stringList(json['places']).toSet(),
      events: stringList(json['events']).toSet(),
      emotions: stringList(json['emotions']).toSet(),
      motivations: stringList(json['motivations']).toSet(),
      values: stringList(json['values']).toSet(),
      fears: stringList(json['fears']).toSet(),
    );
  }
}

/// The author's answer, as written and as read.
class AuthorResponseAnalysis {
  const AuthorResponseAnalysis({
    required this.rawText,
    this.intents = const {ResponseIntent.answer},
    this.terms = const ResponseTerms(),
  });

  /// An answer read as nothing in particular: a plain answer with no terms. What a
  /// caller gets when no reader is available, and what an empty reading falls back
  /// to. The engine works with it, and simply learns less.
  const AuthorResponseAnalysis.plain(String text)
    : this(rawText: text, intents: const {ResponseIntent.answer});

  /// The author's words, exactly as they wrote them.
  final String rawText;

  final Set<ResponseIntent> intents;
  final ResponseTerms terms;

  bool get isUncertain => intents.contains(ResponseIntent.uncertain);
  bool get isCorrection => intents.contains(ResponseIntent.correction);
  bool get isDisagreement => intents.contains(ResponseIntent.disagreement);
  bool get hasSeveralPossibilities =>
      intents.contains(ResponseIntent.multiplePossibilities);
  bool get asksBack => intents.contains(ResponseIntent.questionBack);
  bool get changesTopic => intents.contains(ResponseIntent.topicChange);
  bool get wantsStop => intents.contains(ResponseIntent.stop);
  bool get skips => intents.contains(ResponseIntent.skip);

  /// The number of words, which is all the engine needs to know about length.
  int get wordCount =>
      rawText.trim().isEmpty ? 0 : rawText.trim().split(RegExp(r'\s+')).length;

  /// Nothing was said.
  bool get isEmpty => rawText.trim().isEmpty;

  /// A real answer: said something, wasn't a pass, a stop or an "I don't know".
  ///
  /// Several possibilities count as an answer to the conversation and **not** as
  /// settled: brainstorming is never treated as confirmed (plan 2.9).
  bool get isEngaged =>
      !isEmpty && !isUncertain && !skips && !wantsStop && wordCount >= 2;

  /// Whether this is long enough to call exploratory. A matter of words only.
  bool get isLong => wordCount >= 60;

  Map<String, Object?> toJson() => {
    'rawText': rawText,
    'intents': [for (final i in intents) i.name]..sort(),
    'terms': terms.toJson(),
  };

  static AuthorResponseAnalysis? fromJson(Object? json) {
    if (json is! Map) return null;
    final text = json['rawText'];
    if (text is! String) return null;
    final raw = json['intents'];
    final intents = <ResponseIntent>{};
    if (raw is List) {
      for (final e in raw) {
        final intent = enumByNameOrNull(ResponseIntent.values, e);
        if (intent != null) intents.add(intent);
      }
    }
    return AuthorResponseAnalysis(
      rawText: text,
      intents: intents.isEmpty ? const {ResponseIntent.answer} : intents,
      terms: ResponseTerms.fromJson(json['terms']),
    );
  }
}
