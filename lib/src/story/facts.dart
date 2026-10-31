/// What the extractor produces and the index stores: a fact is one event or state a
/// passage says, with the exact words and place in the source it came from.
library;

import 'labels.dart';

/// True when [a] and [b] name the same thing. Items and places are told apart by word
/// lists, and a word like "gate" or "door" can be either depending on the sentence, so
/// `item_gate` and `place_gate` are the same thing; characters are never merged with
/// either.
bool sameEntity(String? a, String? b) {
  if (a == null || b == null) return false;
  if (a == b) return true;
  String? core(String id) {
    for (final p in const ['item_', 'place_']) {
      if (id.startsWith(p)) return id.substring(p.length);
    }
    return null;
  }

  final ca = core(a), cb = core(b);
  return ca != null && ca == cb;
}

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
  const Attribution({
    required this.speaker,
    required this.kind,
    this.verb,
    this.recipient,
  });
  final String? speaker;

  /// `reported` (said, told, quoted) or `belief` (thought, believed).
  final String kind;

  /// The verb that introduced it (`tell`, `read`, `believe`), when there was one.
  final String? verb;

  /// Who was told, when the sentence names them: `Mara told Iven that ...`.
  final String? recipient;

  Map<String, dynamic> toJson() => {'speaker': speaker, 'kind': kind};

  @override
  bool operator ==(Object other) =>
      other is Attribution && other.speaker == speaker && other.kind == kind;

  @override
  int get hashCode => Object.hash(speaker, kind);
}

/// Something a sentence says about what a character took in, found while extracting
/// facts: "Iven saw Mara hide the key", "Mara told Iven that she hid it", "Iven did not
/// know that ...". It points at the facts of the embedded clause; turning a cue into a
/// knowledge event (state, route, time) is a separate stage (`knowledge.dart`).
class KnowledgeCue {
  const KnowledgeCue({
    required this.sourceId,
    required this.sentenceStart,
    required this.sentenceEnd,
    required this.verb,
    required this.kind,
    required this.factOrders,
    this.knower,
    this.recipient,
    this.negated = false,
    this.possible = false,
  });

  final String sourceId;
  final int sentenceStart;
  final int sentenceEnd;

  /// The introducing verb's lemma.
  final String verb;

  /// `reported`, `belief`, `factive` (the narrator also asserts the clause),
  /// `misremember`, or `perceived` (a bare-infinitive perception: "saw her hide it").
  final String kind;

  /// `Fact.order` of the facts of the embedded clause; the first is the proposition.
  final List<int> factOrders;

  /// The subject of the introducing verb.
  final String? knower;

  /// The person told, when named.
  final String? recipient;

  /// The introducing verb was negated ("did not know that").
  final bool negated;

  /// The introducing verb was hedged ("might know that").
  final bool possible;
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
      sameEntity(subject, entityId) ||
      sameEntity(object, entityId) ||
      sameEntity(recipient?.entityId, entityId) ||
      sameEntity(location?.entityId, entityId) ||
      sameEntity(destination?.entityId, entityId) ||
      sameEntity(origin?.entityId, entityId);

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
    this.kind,
  });

  final String sourceId;

  /// Where the passage sits in the project's hierarchy: `canon`, `manuscript`,
  /// `note` or `discovery`. Null when the caller did not say.
  final String? kind;
  final int start;
  final int end;

  /// The exact text of the source between [start] and [end].
  final String quote;

  Map<String, dynamic> toJson() => {
    'source_id': sourceId,
    'start': start,
    'end': end,
    'quote': quote,
    if (kind != null) 'kind': kind,
  };
}
