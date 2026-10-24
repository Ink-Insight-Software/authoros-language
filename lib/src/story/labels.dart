/// The stable labels of story grounding (docs/story-grounding/schema.md), and the
/// token every stage works on.
///
/// The part-of-speech tags are the Universal Dependencies UPOS set, less `X` and `SYM`,
/// which story text does not need. A tagger that uses another inventory is mapped to
/// these at the boundary (`pennToUpos`) and the rest of the system never sees its tags.
library;

/// Part of speech: the Universal Dependencies UPOS tags this system uses.
enum Upos {
  noun('NOUN'),
  propn('PROPN'),
  verb('VERB'),
  adj('ADJ'),
  adv('ADV'),
  pron('PRON'),
  det('DET'),
  adp('ADP'),
  aux('AUX'),
  cconj('CCONJ'),
  sconj('SCONJ'),
  part('PART'),
  num('NUM'),
  intj('INTJ'),
  punct('PUNCT');

  const Upos(this.label);

  /// The tag as written in data: `PROPN`.
  final String label;

  static Upos? parse(String label) {
    for (final u in values) {
      if (u.label == label) return u;
    }
    return null;
  }
}

enum EntityType {
  character('CHARACTER', 'char'),
  place('PLACE', 'place'),
  item('ITEM', 'item'),
  group('GROUP', 'group'),
  time('TIME', 'time'),
  event('EVENT', 'event'),
  other('OTHER', 'other');

  const EntityType(this.label, this.prefix);

  final String label;

  /// The prefix of an entity id of this type: `char_mara`.
  final String prefix;

  static EntityType? parse(String label) {
    for (final t in values) {
      if (t.label == label) return t;
    }
    return null;
  }
}

/// What a phrase does in an event or fact.
enum SemanticRole {
  subject,
  action,
  object,
  attribute,
  location,
  time,
  manner,
  cause,
  purpose,
  recipient,
  source,
}

/// Whether a statement is a fact, an inference, a suggestion, a gap or a clash.
/// Data, never inferred from how confident the wording is.
enum EvidenceStatus {
  stated('STATED'),
  derived('DERIVED'),
  proposed('PROPOSED'),
  unknown('UNKNOWN'),
  conflict('CONFLICT');

  const EvidenceStatus(this.label);

  final String label;

  static EvidenceStatus? parse(String label) {
    for (final s in values) {
      if (s.label == label) return s;
    }
    return null;
  }
}

/// A word, with where it sits in the stored text. Offsets are into the exact string
/// the source was ingested with: nothing here ever re-derives them.
class Token {
  const Token({
    required this.text,
    required this.start,
    required this.end,
    this.pos,
    this.lemma,
    this.entityId,
    this.entityType,
    this.role,
  });

  final String text;
  final int start;
  final int end;
  final Upos? pos;
  final String? lemma;

  /// The entity this token mentions, when the linker resolved one.
  final String? entityId;
  final EntityType? entityType;
  final SemanticRole? role;

  String get lower => text.toLowerCase();

  Token copyWith({
    Upos? pos,
    String? lemma,
    Object? entityId = _keep,
    Object? entityType = _keep,
    Object? role = _keep,
  }) => Token(
    text: text,
    start: start,
    end: end,
    pos: pos ?? this.pos,
    lemma: lemma ?? this.lemma,
    entityId: identical(entityId, _keep) ? this.entityId : entityId as String?,
    entityType: identical(entityType, _keep)
        ? this.entityType
        : entityType as EntityType?,
    role: identical(role, _keep) ? this.role : role as SemanticRole?,
  );

  static const _keep = Object();

  @override
  String toString() => '$text/${pos?.label ?? '?'}';
}

/// One sentence of a source: its span and its tokens.
class Sentence {
  const Sentence({
    required this.start,
    required this.end,
    required this.text,
    required this.tokens,
  });

  final int start;
  final int end;
  final String text;
  final List<Token> tokens;

  Sentence withTokens(List<Token> tokens) =>
      Sentence(start: start, end: end, text: text, tokens: tokens);
}

/// Maps a Penn Treebank tag, the inventory many taggers use, to UPOS. Returns null
/// for a tag that has no place here (`SYM`, `FW`, `LS`...), so the caller decides.
///
/// `TO` is ambiguous (infinitive marker or preposition) and `RP` (particle) can be
/// either a particle or an adposition; the context-free choice is made here and a
/// caller with the next word should refine it.
Upos? pennToUpos(String tag) => switch (tag) {
  'NN' || 'NNS' => Upos.noun,
  'NNP' || 'NNPS' => Upos.propn,
  'VB' || 'VBD' || 'VBG' || 'VBN' || 'VBP' || 'VBZ' => Upos.verb,
  'MD' => Upos.aux,
  'JJ' || 'JJR' || 'JJS' => Upos.adj,
  'RB' || 'RBR' || 'RBS' || 'WRB' => Upos.adv,
  'PRP' || 'WP' || 'EX' => Upos.pron,
  'PRP\$' || 'WP\$' || 'DT' || 'PDT' || 'WDT' => Upos.det,
  'IN' => Upos.adp,
  'TO' => Upos.part,
  'RP' => Upos.adv,
  'CC' => Upos.cconj,
  'POS' => Upos.part,
  'CD' => Upos.num,
  'UH' => Upos.intj,
  '.' ||
  ',' ||
  ':' ||
  '``' ||
  "''" ||
  '-LRB-' ||
  '-RRB-' ||
  '\$' ||
  '#' => Upos.punct,
  _ => null,
};
