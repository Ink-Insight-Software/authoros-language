/// The story's facts, kept with the exact text they came from, and the one place a
/// question is asked.
library;

import 'answer.dart';
import 'entities.dart';
import 'extractor.dart';
import 'facts.dart';
import 'question.dart';
import 'retriever.dart';

/// Where a passage sits among the author's material. Used to order evidence and to
/// say where a statement came from; a lower-priority source never silently overrides
/// a higher one, a clash is reported as a conflict.
enum SourceKind {
  /// Author-approved canon.
  canon,

  /// The manuscript text.
  manuscript,

  /// Notes the author wrote.
  note,

  /// Something found in the text that the author has not yet approved.
  discovery,
}

class StorySource {
  const StorySource({required this.id, required this.text, required this.kind});
  final String id;
  final String text;
  final SourceKind kind;
}

class StoryIndex {
  StoryIndex(this.registry) : _extractor = FactExtractor(registry: registry);

  final EntityRegistry registry;
  FactExtractor _extractor;
  final _sources = <StorySource>[];
  final _facts = <Fact>[];
  static const _retriever = StoryRetriever();

  List<StorySource> get sources => List.unmodifiable(_sources);
  List<Fact> get facts => List.unmodifiable(_facts);
  FactExtractor get extractor => _extractor;

  /// Adds a passage in reading order and extracts its facts. Later passages may
  /// resolve pronouns against earlier ones.
  List<Fact> ingest(
    String sourceId,
    String text, {
    SourceKind kind = SourceKind.manuscript,
  }) {
    if (_sources.any((s) => s.id == sourceId)) {
      throw ArgumentError(
        'source $sourceId is already in the index; use replace',
      );
    }
    _sources.add(StorySource(id: sourceId, text: text, kind: kind));
    final out = _extractor.extract(sourceId, text);
    _facts.addAll(out.facts);
    return out.facts;
  }

  /// Changes a passage. Rebuilt from scratch, in the original order, so pronoun
  /// resolution and "later" stay consistent.
  void replace(String sourceId, String text) {
    final updated = [
      for (final s in _sources)
        s.id == sourceId ? StorySource(id: s.id, text: text, kind: s.kind) : s,
    ];
    _rebuild(updated);
  }

  void remove(String sourceId) => _rebuild([
    for (final s in _sources)
      if (s.id != sourceId) s,
  ]);

  void _rebuild(List<StorySource> sources) {
    _sources.clear();
    _facts.clear();
    _extractor = FactExtractor(registry: registry);
    for (final s in sources) {
      ingest(s.id, s.text, kind: s.kind);
    }
  }

  StorySource? source(String id) {
    for (final s in _sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  EvidenceRef _refOf(Fact f) {
    final src = source(f.sourceId)!;
    return EvidenceRef(
      sourceId: f.sourceId,
      start: f.sentenceStart,
      end: f.sentenceEnd,
      quote: src.text.substring(f.sentenceStart, f.sentenceEnd),
      kind: src.kind.name,
    );
  }

  /// Parses and answers [question].
  Answer ask(String question) =>
      answer(QuestionParser(_extractor).parse(question));

  /// Answers an already parsed question.
  Answer answer(StoryQuestion question) =>
      _retriever.answer(question, _facts, _refOf);
}
