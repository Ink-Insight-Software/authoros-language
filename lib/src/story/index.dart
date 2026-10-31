/// The story's facts, kept with the exact text they came from, and the one place a
/// question is asked.
library;

import 'answer.dart';
import 'entities.dart';
import 'extractor.dart';
import 'facts.dart';
import 'knowledge.dart';
import 'knowledge_question.dart';
import 'labels.dart';
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
  const StorySource({
    required this.id,
    required this.text,
    required this.kind,
    required this.storyTimeId,
  });
  final String id;
  final String text;
  final SourceKind kind;

  /// Where in the story this passage happens (a timeline id).
  final String storyTimeId;
}

class StoryIndex {
  /// One index is one draft of one project: facts never cross either boundary. Pass
  /// [timeline] when the application already keeps story order; otherwise reading order
  /// is story order.
  StoryIndex(this.registry, {StoryTimeline? timeline, this.draftId})
    : timeline = timeline ?? StoryTimeline(),
      _extractor = FactExtractor(registry: registry);

  final EntityRegistry registry;

  /// Story order, shared with the knowledge queries.
  final StoryTimeline timeline;

  /// Which draft or version this index describes; every answer is about this one.
  final String? draftId;
  FactExtractor _extractor;
  final _sources = <StorySource>[];
  final _facts = <Fact>[];
  final _cues = <KnowledgeCue>[];
  final _authorRecords = <AuthorKnowledgeRecord>[];
  KnowledgeIndex? _knowledge;
  static const _retriever = StoryRetriever();

  List<StorySource> get sources => List.unmodifiable(_sources);
  List<Fact> get facts => List.unmodifiable(_facts);
  FactExtractor get extractor => _extractor;

  /// Adds a passage in reading order and extracts its facts. Later passages may
  /// resolve pronouns against earlier ones.
  ///
  /// [storyTimeId] is where the passage happens in the story (a timeline id); without it
  /// the passage is placed at the end of the story so far.
  List<Fact> ingest(
    String sourceId,
    String text, {
    SourceKind kind = SourceKind.manuscript,
    String? storyTimeId,
  }) {
    if (_sources.any((s) => s.id == sourceId)) {
      throw ArgumentError(
        'source $sourceId is already in the index; use replace',
      );
    }
    final time = storyTimeId ?? sourceId;
    timeline.add(time);
    _sources.add(
      StorySource(id: sourceId, text: text, kind: kind, storyTimeId: time),
    );
    final out = _extractor.extract(sourceId, text);
    _facts.addAll(out.facts);
    _cues.addAll(out.cues);
    _knowledge = null;
    return out.facts;
  }

  /// Changes a passage. Rebuilt from scratch, in the original order, so pronoun
  /// resolution and "later" stay consistent.
  void replace(String sourceId, String text) {
    final updated = [
      for (final s in _sources)
        s.id == sourceId
            ? StorySource(
                id: s.id,
                text: text,
                kind: s.kind,
                storyTimeId: s.storyTimeId,
              )
            : s,
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
    _cues.clear();
    _knowledge = null;
    _extractor = FactExtractor(registry: registry);
    for (final s in sources) {
      ingest(s.id, s.text, kind: s.kind, storyTimeId: s.storyTimeId);
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

  EvidenceRef _refAt(String sourceId, int start, int end) {
    final src = source(sourceId)!;
    return EvidenceRef(
      sourceId: sourceId,
      start: start,
      end: end,
      quote: src.text.substring(start, end),
      kind: src.kind.name,
    );
  }

  // ---- character knowledge ----------------------------------------------------------

  /// Records what the author says a character knows or does not, for a proposition
  /// written as a sentence ("Mara hid the key."). This is the only way an
  /// AUTHOR_CONFIRMED_UNAWARE or AUTHOR_ENTERED state enters.
  void addAuthorKnowledge(AuthorKnowledgeRecord record) {
    timeline.add(record.storyTimeId);
    _authorRecords.add(record);
    _knowledge = null;
  }

  /// The knowledge events and queries for this draft. Rebuilt from the passages and
  /// author records whenever they change, so it is never out of date and never a second
  /// source of truth.
  KnowledgeIndex get knowledge => _knowledge ??= KnowledgeIndex(
    facts: _facts,
    cues: _cues,
    sourceTimes: {for (final s in _sources) s.id: s.storyTimeId},
    timeline: timeline,
    evidenceAt: _refAt,
    authorRecords: _authorRecords,
    propositionOf: (text) {
      final f = _extractor.propositionFrom(text);
      return f == null ? null : Proposition.fromFact(f);
    },
  );

  /// Reads and answers a knowledge question ("Does Iven know Mara hid the key by
  /// Chapter 3?", "Who knows ...?", "When did Iven learn that ...?").
  KnowledgeAnswer askKnowledge(String question) {
    final q = KnowledgeQuestionParser(
      registry,
      _extractor,
      timeline,
    ).parse(question);
    return answerKnowledge(q);
  }

  KnowledgeAnswer answerKnowledge(KnowledgeQuestion q) {
    if (q.kind == 'unsupported' || q.proposition == null) {
      return KnowledgeAnswer(
        kind: q.kind,
        status: EvidenceStatus.unknown,
        note: 'question not understood',
      );
    }
    if (q.atText != null && q.at == null) {
      return KnowledgeAnswer(
        kind: q.kind,
        status: EvidenceStatus.unknown,
        note: 'story point not found',
      );
    }
    return switch (q.kind) {
      'knows' => knowledge.knowsAt(q.characterId!, q.proposition!, at: q.at),
      'who_knows' => knowledge.whoKnows(q.proposition!, at: q.at),
      _ => knowledge.whenLearned(q.characterId!, q.proposition!),
    };
  }

  /// Possible knowledge leaks, as review items for the author.
  List<KnowledgeLeakReview> knowledgeLeaks() => knowledge.leaks();

  /// Parses and answers [question].
  Answer ask(String question) =>
      answer(QuestionParser(_extractor).parse(question));

  /// Answers an already parsed question.
  Answer answer(StoryQuestion question) =>
      _retriever.answer(question, _facts, _refOf);
}
