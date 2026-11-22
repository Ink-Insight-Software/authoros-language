/// What the author tells a character about how they answered, and how that shapes the
/// next answers.
///
/// This is how a character adapts without retraining anything: the author's own ratings
/// and notes are kept per character and put in front of the model as guidance about
/// *manner* (how to answer), never as facts about the story. Feedback is never canon.
library;

enum FeedbackRating { good, notQuite }

class LiveFeedback {
  const LiveFeedback({
    required this.id,
    required this.characterId,
    required this.at,
    required this.rating,
    required this.authorText,
    required this.characterText,
    this.note,
    this.live = false,
  });

  final String id;
  final String characterId;
  final DateTime at;
  final FeedbackRating rating;

  /// What the author said that the character answered ("" if the character spoke first).
  final String authorText;

  /// What the character said.
  final String characterText;

  /// What the author wanted instead, in their own words.
  final String? note;

  /// Whether a live voice wrote the line (false: Companion's own wording).
  final bool live;

  Map<String, Object?> toJson() => {
    'id': id,
    'characterId': characterId,
    'at': at.toUtc().toIso8601String(),
    'rating': rating.name,
    'authorText': authorText,
    'characterText': characterText,
    if (note != null) 'note': note,
    'live': live,
  };

  /// Read tolerantly: anything missing or of the wrong kind is not feedback.
  static LiveFeedback? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'], who = json['characterId'], at = json['at'];
    final said = json['authorText'], spoke = json['characterText'];
    if (id is! String || who is! String || at is! String) {
      return null;
    }
    if (said is! String || spoke is! String || spoke.trim().isEmpty) {
      return null;
    }
    final time = DateTime.tryParse(at);
    if (time == null) {
      return null;
    }
    final rating = FeedbackRating.values.where((r) => r.name == json['rating']);
    if (rating.isEmpty) {
      return null;
    }
    final note = json['note'];
    return LiveFeedback(
      id: id,
      characterId: who,
      at: time,
      rating: rating.first,
      authorText: said,
      characterText: spoke,
      note: note is String && note.trim().isNotEmpty ? note.trim() : null,
      live: json['live'] == true,
    );
  }
}

/// One answer the author liked, to sound like in manner.
class LiveExample {
  const LiveExample({required this.authorText, required this.characterText});
  final String authorText;
  final String characterText;
}

/// One thing the author asked the character to do differently.
class LiveCorrection {
  const LiveCorrection({
    required this.authorText,
    required this.characterText,
    required this.wanted,
  });
  final String authorText;
  final String characterText;

  /// What the author said they wanted. Empty if they only marked it "not quite".
  final String wanted;
}

/// What a character is told about how to answer, from the author's feedback.
class FeedbackGuidance {
  const FeedbackGuidance({this.liked = const [], this.corrections = const []});

  static const none = FeedbackGuidance();

  final List<LiveExample> liked;
  final List<LiveCorrection> corrections;

  bool get isEmpty => liked.isEmpty && corrections.isEmpty;

  /// Every word of it, so a name the author used may be said back.
  String get allText => [
    for (final l in liked) '${l.authorText} ${l.characterText}',
    for (final c in corrections)
      '${c.authorText} ${c.characterText} ${c.wanted}',
  ].join('\n');

  /// The most recent feedback for [characterId], newest kept: a few answers the author
  /// liked and a few corrections. Bounded, so a long history cannot swamp the prompt.
  static FeedbackGuidance from(
    Iterable<LiveFeedback> all,
    String characterId, {
    int maxLiked = 3,
    int maxCorrections = 4,
    int maxChars = 280,
  }) {
    String clip(String s) {
      final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
      return t.length <= maxChars ? t : '${t.substring(0, maxChars)}…';
    }

    final mine = [
      for (final f in all)
        if (f.characterId == characterId) f,
    ]..sort((a, b) => b.at.compareTo(a.at));
    final liked = <LiveExample>[];
    final corrections = <LiveCorrection>[];
    for (final f in mine) {
      if (f.rating == FeedbackRating.good && liked.length < maxLiked) {
        liked.add(
          LiveExample(
            authorText: clip(f.authorText),
            characterText: clip(f.characterText),
          ),
        );
      } else if (f.rating == FeedbackRating.notQuite &&
          corrections.length < maxCorrections) {
        corrections.add(
          LiveCorrection(
            authorText: clip(f.authorText),
            characterText: clip(f.characterText),
            wanted: clip(f.note ?? ''),
          ),
        );
      }
    }
    return FeedbackGuidance(liked: liked, corrections: corrections);
  }
}
