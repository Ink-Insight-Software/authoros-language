/// Reads the knowledge questions an author asks: "Does Iven know Mara hid the key by
/// Chapter 3?", "Who knows ... by the midpoint?", "When did Iven learn that ...?".
///
/// Three patterns, matched on the words. Anything else is not understood and the answer
/// says so; a question is never guessed at.
library;

import 'entities.dart';
import 'extractor.dart';
import 'knowledge.dart';

class KnowledgeQuestion {
  const KnowledgeQuestion({
    required this.text,
    required this.kind,
    this.characterId,
    this.proposition,
    this.at,
    this.atText,
  });

  final String text;

  /// `knows`, `who_knows`, `when_learned` or `unsupported`.
  final String kind;
  final String? characterId;
  final Proposition? proposition;

  /// The timeline id (or prefix) the question is scoped to, if it named one.
  final String? at;

  /// What the question said ("Chapter 3"), kept even if it matched nothing.
  final String? atText;
}

class KnowledgeQuestionParser {
  const KnowledgeQuestionParser(this.registry, this.extractor, this.timeline);

  final EntityRegistry registry;
  final FactExtractor extractor;
  final StoryTimeline timeline;

  // A story point is only recognised when it names a chapter, scene or the like, so
  // "the key was in the cellar by Chapter 2" keeps "in the cellar" in the clause.
  static final _knows = RegExp(
    r'^(?:does|did|do|has|had)\s+(\S+)\s+(?:know|learn|realize|realise|find out|hear|see)\s+(?:that\s+)?(.+?)(?:\s+(?:by|in|at)\s+((?:chapter|scene|act|part|book|section|prologue|epilogue)\b.*?))?\s*\??$',
    caseSensitive: false,
  );
  static final _who = RegExp(
    r'^who\s+(?:knows|knew|learned|learnt)\s+(?:that\s+)?(.+?)(?:\s+(?:by|in|at)\s+((?:chapter|scene|act|part|book|section|prologue|epilogue)\b.*?))?\s*\??$',
    caseSensitive: false,
  );
  static final _when = RegExp(
    r'^when\s+(?:did|does|do)\s+(\S+)\s+(?:learn|know|find out|realize|realise)\s+(?:that\s+|about\s+)?(.+?)\s*\??$',
    caseSensitive: false,
  );

  KnowledgeQuestion parse(String text) {
    final t = text.trim();
    KnowledgeQuestion unsupported() =>
        KnowledgeQuestion(text: text, kind: 'unsupported');

    Proposition? prop(String clause) {
      final f = extractor.propositionFrom(clause);
      return f == null ? null : Proposition.fromFact(f);
    }

    String? timeId(String? words) {
      if (words == null) return null;
      final at = timeline.resolveLabel(words);
      return at == null ? null : timeline.idAt(at);
    }

    final k = _knows.firstMatch(t);
    if (k != null) {
      final who = registry.byName(k.group(1)!);
      final p = prop(k.group(2)!);
      if (who == null || p == null) return unsupported();
      final atWords = k.group(3);
      return KnowledgeQuestion(
        text: text,
        kind: 'knows',
        characterId: who.id,
        proposition: p,
        at: timeId(atWords),
        atText: atWords,
      );
    }
    final w = _who.firstMatch(t);
    if (w != null) {
      final p = prop(w.group(1)!);
      if (p == null) return unsupported();
      final atWords = w.group(2);
      return KnowledgeQuestion(
        text: text,
        kind: 'who_knows',
        proposition: p,
        at: timeId(atWords),
        atText: atWords,
      );
    }
    final n = _when.firstMatch(t);
    if (n != null) {
      final who = registry.byName(n.group(1)!);
      final p = prop(n.group(2)!);
      if (who == null || p == null) return unsupported();
      return KnowledgeQuestion(
        text: text,
        kind: 'when_learned',
        characterId: who.id,
        proposition: p,
      );
    }
    return unsupported();
  }
}
