/// The result of asking the story a question: the answer, how sure the story is about
/// it, and the exact words it rests on.
library;

import 'facts.dart';
import 'labels.dart';
import 'question.dart';

class Answer {
  const Answer({
    required this.question,
    required this.status,
    this.answer,
    this.answers = const [],
    this.evidence = const [],
    this.note,
    this.offerProposal = false,
    this.attribution,
    this.trace = const [],
  });

  final StoryQuestion question;

  /// STATED, DERIVED, UNKNOWN or CONFLICT. Never PROPOSED: proposals are made by a
  /// separate stage and never come out of retrieval.
  final EvidenceStatus status;

  /// The answer, in the words of the source, or null for UNKNOWN and CONFLICT.
  final String? answer;

  /// Every candidate, for CONFLICT (the clashing answers) or a question with several.
  final List<String> answers;

  /// Where in the author's text the answer comes from. Empty for a plain UNKNOWN.
  final List<EvidenceRef> evidence;

  /// Why, when the status needs more than a word: `later moved`, `possibility only`.
  final String? note;

  /// True when the story says nothing and the author could be offered ideas.
  final bool offerProposal;

  /// Who said it, when it was reported speech or a belief and not the narrator.
  final Attribution? attribution;

  /// The steps retrieval took, for a reviewer. Not shown to the author by default.
  final List<String> trace;

  Set<String> get evidenceSourceIds => {for (final e in evidence) e.sourceId};

  Map<String, dynamic> toJson() => {
    'question': question.toJson(),
    'status': status.label,
    'answer': answer,
    'answers': answers,
    'evidence': [for (final e in evidence) e.toJson()],
    'note': note,
    'offer_proposal': offerProposal,
    'attribution': attribution?.toJson(),
  };
}
