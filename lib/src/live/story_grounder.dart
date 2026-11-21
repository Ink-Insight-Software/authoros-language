/// Gives a character the part of the story they have actually lived, and checks what
/// they say against the whole of it.
///
/// Built on the author's own text only (`StoryIndex`): what a character knows is what
/// the passages say they know, up to the point in the story being talked about.
library;

import '../story/story.dart';
import 'live_models.dart';

class StoryGrounder {
  StoryGrounder(this.index);

  final StoryIndex index;

  static String _state(KnowledgeState s) => switch (s) {
    KnowledgeState.knows => 'knows',
    KnowledgeState.believes => 'believes',
    KnowledgeState.suspects => 'suspects',
    KnowledgeState.misremembers => 'misremembers',
    _ => '',
  };

  /// What [characterId] knows, believes or suspects at the end of story point [at]
  /// (the end of the story if null), as the author's own sentences, latest last.
  /// "Does not know yet" is never listed: a character is told only what they know.
  List<StoryFact> factsFor(String characterId, {String? at, int max = 14}) {
    final k = index.knowledge;
    final limit = at == null
        ? k.timeline.endPosition
        : (k.timeline.endOf(at) ?? k.timeline.endPosition);
    final seen = <String>{};
    final out = <StoryFact>[];
    final events =
        k.events
            .where((e) => e.characterId == characterId && !e.possible)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    for (final e in events) {
      final end = k.timeline.endOf(e.storyTimeId);
      if (end != null && end > limit) continue;
      final state = _state(e.state);
      if (state.isEmpty) continue;
      if (e.validUntil != null) {
        final until = k.timeline.endOf(e.validUntil!);
        if (until != null && until <= limit) continue;
      }
      final quote = e.evidence.quote.trim();
      if (quote.isEmpty || !seen.add(quote)) continue;
      out.add(StoryFact(text: quote, state: state, source: e.sourceId));
    }
    return out.length <= max ? out : out.sublist(out.length - max);
  }

  /// What is wrong with [reply] said by [characterId] at story point [at]: it
  /// contradicts the story, or states as fact something the character does not know.
  /// Empty when nothing is. Reading is rule-based and cautious: a reply it cannot
  /// read is not blocked.
  List<String> problemsIn(String characterId, String reply, {String? at}) {
    final found = <String>[];
    final List<Fact> facts;
    try {
      facts = index.extractor.factsFrom(reply, speaker: characterId);
    } on Object {
      return const [];
    }
    final k = index.knowledge;
    for (final f in facts) {
      if (f.modality != 'certain' || f.attribution != null) continue;
      final p = Proposition.fromFact(f);
      final canon = k.canonStatus(p);
      final sentence =
          reply.length >= f.sentenceEnd && f.sentenceEnd > f.sentenceStart
          ? reply.substring(f.sentenceStart, f.sentenceEnd).trim()
          : reply.trim();
      // A claim the story denies, or a denial of what the story says. A character may
      // lie in a story; here that is held back for the author to decide, never said.
      if ((canon == false && f.polarity == 'affirmed') ||
          (canon == true && f.polarity == 'negated')) {
        found.add('contradicts the story: "$sentence"');
        continue;
      }
      if (canon == true &&
          f.polarity == 'affirmed' &&
          f.subject != null &&
          !sameEntity(f.subject, characterId)) {
        final a = k.knowsAt(characterId, p, at: at);
        if (a.state == null ||
            a.state == KnowledgeState.authorConfirmedUnaware ||
            a.state == KnowledgeState.unawareInText) {
          found.add('says what the character does not know: "$sentence"');
        }
      }
    }
    return found;
  }

  /// A checker for one character at one point, for `LiveConversation`.
  List<String> Function(String) checker(String characterId, {String? at}) =>
      (reply) => problemsIn(characterId, reply, at: at);
}
