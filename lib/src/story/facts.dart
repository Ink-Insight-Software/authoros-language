/// What the extractor produces and the index stores: a fact is one event or state a
/// passage says, with the exact words and place in the source it came from.
library;

import 'labels.dart';

/// A place, a destination or a recipient: the words used, and the entity they name
/// when one was found.
class SlotValue {
  const SlotValue({required this.text, this.entityId});
  final String text;
  final String? entityId;

  Map<String, dynamic> toJson() => {
    'text': text,
    if (entityId != null) 'entity_id': entityId,
  };
}

/// Who said or believed it, when a fact is not the narrator's own statement.
class Attribution {
  const Attribution({required this.speaker, required this.kind});
  final String? speaker;

  /// `reported` (said, told, quoted) or `belief` (thought, believed).
  final String kind;

  Map<String, dynamic> toJson() => {'speaker': speaker, 'kind': kind};

  @override
  bool operator ==(Object other) =>
      other is Attribution && other.speaker == speaker && other.kind == kind;

  @override
  int get hashCode => Object.hash(speaker, kind);
}

class Fact {
  const Fact({
    required this.factId,
    required this.sourceId,
    required this.order,
    required this.sentenceStart,
    required this.sentenceEnd,
    required this.relation,
    this.subject,
    this.subjectText,
    this.object,
    this.objectText,
    this.location,
    this.destination,
    this.origin,
    this.recipient,
    this.time,
    this.manner,
    this.attribute,
    this.polarity = 'affirmed',
    this.modality = 'certain',
    this.attribution,
    this.unresolvedSubject = false,
  });

  final String factId;
  final String sourceId;

  /// Position of this fact in the ingestion order, for "later" and "earlier".
  final int order;

  /// The sentence the fact came from, as offsets into the source text.
  final int sentenceStart;
  final int sentenceEnd;

  /// The verb's lemma, or `be` for a state.
  final String relation;
  final String? subject;
  final String? subjectText;
  final String? object;
  final String? objectText;
  final SlotValue? location;
  final SlotValue? destination;
  final SlotValue? origin;
  final SlotValue? recipient;
  final String? time;
  final String? manner;
  final String? attribute;

  /// `affirmed` or `negated`.
  final String polarity;

  /// `certain` or `possible`.
  final String modality;
  final Attribution? attribution;

  /// True when the subject was a pronoun that could not be resolved to one entity.
  final bool unresolvedSubject;

  bool involves(String entityId) =>
      subject == entityId ||
      object == entityId ||
      recipient?.entityId == entityId ||
      location?.entityId == entityId ||
      destination?.entityId == entityId ||
      origin?.entityId == entityId;

  Map<String, dynamic> toJson() => {
    'fact_id': factId,
    'source_id': sourceId,
    'evidence_span': [sentenceStart, sentenceEnd],
    'subject': subject,
    'relation': relation,
    'object': object,
    'location': location?.entityId,
    'destination': destination?.entityId,
    'origin': origin?.entityId,
    'recipient': recipient?.entityId,
    'time': time,
    'manner': manner,
    'attribute': attribute,
    'polarity': polarity,
    'modality': modality,
    'attribution': attribution?.toJson(),
    'status': EvidenceStatus.stated.label,
    if (unresolvedSubject) 'unresolved_subject': true,
  };
}

/// A pointer back into the author's text, exact enough to show the words.
class EvidenceRef {
  const EvidenceRef({
    required this.sourceId,
    required this.start,
    required this.end,
    required this.quote,
  });

  final String sourceId;
  final int start;
  final int end;

  /// The exact text of the source between [start] and [end].
  final String quote;

  Map<String, dynamic> toJson() => {
    'source_id': sourceId,
    'start': start,
    'end': end,
    'quote': quote,
  };
}
