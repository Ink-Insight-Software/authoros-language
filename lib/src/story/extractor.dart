/// Turns tagged sentences into facts: who did what to what, where, when and how, with
/// negation, modality and who said it.
///
/// Rule-based and inspectable. Every decision is a named step over tagged tokens: chunk
/// noun phrases, find the verb group, find the subject before it and the objects and
/// prepositional phrases after it, then fill the slots. A clause the rules do not
/// understand yields no fact (silence is safe; a wrong fact is not). The stage also
/// writes its decisions back onto the tokens (role, entity) so a reviewer can see them.
library;

import 'entities.dart';
import 'facts.dart';
import 'labels.dart';
import 'lexicon.dart';
import 'tagger.dart';
import 'tokenizer.dart';

class ExtractionOutput {
  const ExtractionOutput({
    required this.sentences,
    required this.facts,
    this.cues = const [],
  });
  final List<Sentence> sentences;
  final List<Fact> facts;

  /// What the sentences say characters took in (see [KnowledgeCue]).
  final List<KnowledgeCue> cues;
}

class _Np {
  _Np({
    required this.start,
    required this.end,
    required this.head,
    this.nouns = const [],
    this.adjs = const [],
    this.pronoun = false,
    this.proper = false,
  });
  final int start;
  final int end; // exclusive
  final int head;
  final List<int> nouns;
  final List<int> adjs;
  final bool pronoun;
  final bool proper;
}

class _Mention {
  _Mention(this.sentence, this.entityId, this.type, this.role);
  final int sentence;
  final String entityId;
  final EntityType type;
  final SemanticRole role;
}

class _Ref {
  const _Ref(this.entityId, this.text, {this.unresolved = false});
  final String? entityId;
  final String text;
  final bool unresolved;
}

class FactExtractor {
  FactExtractor({required this.registry, Tagger? tagger})
    : tagger = tagger ?? RuleTagger(registry: registry);

  final EntityRegistry registry;
  final Tagger tagger;
  static const _tokenizer = StoryTokenizer();
  static final _lex = StoryLexicon.instance;

  final _history = <_Mention>[];

  /// The words last used for each entity, so a pronoun's answer is a name, not "she".
  final _surface = <String, String>{};
  int _sentenceCounter = 0;
  int _order = 0;

  /// Characters or items the text mentioned that the project did not define. They get
  /// an id from their name so a question can find them, and are listed here so the
  /// author can be offered them as new characters.
  final unregisteredNames = <String>{};

  ExtractionOutput extract(String sourceId, String text) {
    final sentences = tagger.tag(_tokenizer.tokenize(text));
    final facts = <Fact>[];
    final cues = <KnowledgeCue>[];
    final out = <Sentence>[];
    var n = 0;
    for (final s in sentences) {
      _sentenceCounter++;
      final w = _Work(sourceId, text, s);
      if (!s.text.trimRight().endsWith('?')) {
        _sentence(w);
      }
      for (final f in w.facts) {
        n++;
        facts.add(_numbered(f, '${sourceId}_f$n'));
      }
      cues.addAll(w.cues);
      out.add(s.withTokens(w.tokens));
    }
    return ExtractionOutput(sentences: out, facts: facts, cues: cues);
  }

  Fact _numbered(Fact f, String id) => Fact(
    factId: id,
    sourceId: f.sourceId,
    order: f.order,
    sentenceStart: f.sentenceStart,
    sentenceEnd: f.sentenceEnd,
    relation: f.relation,
    subject: f.subject,
    subjectText: f.subjectText,
    object: f.object,
    objectText: f.objectText,
    location: f.location,
    destination: f.destination,
    origin: f.origin,
    recipient: f.recipient,
    time: f.time,
    manner: f.manner,
    attribute: f.attribute,
    polarity: f.polarity,
    modality: f.modality,
    attribution: f.attribution,
    unresolvedSubject: f.unresolvedSubject,
  );

  /// The entity ids a question mentions, in order, without touching the coreference
  /// history. Pronouns are skipped (a question has no earlier sentence to resolve them
  /// against) and so is "what colour": the wh-word's noun is the thing asked about.
  List<String> entitiesIn(String text) {
    final keep = {...unregisteredNames};
    final ids = <String>[];
    for (final s in tagger.tag(_tokenizer.tokenize(text))) {
      final w = _Work('question', text, s);
      for (final np in _nps(w, 0, w.tokens.length)) {
        if (np.pronoun) continue;
        final first = w.tokens[np.start].lower;
        if (first == 'what' || first == 'which' || first == 'whose') continue;
        final id = _refOf(w, np, place: false).entityId;
        if (id != null && !ids.contains(id)) ids.add(id);
      }
    }
    unregisteredNames
      ..clear()
      ..addAll(keep);
    return ids;
  }

  /// The main fact of a clause typed as a question or a note ("Mara hid the key"), with
  /// no effect on the extractor's memory of earlier sentences: no pronoun history, fact
  /// numbering or unregistered names are changed.
  Fact? propositionFrom(String clause) {
    final savedHistory = List<_Mention>.of(_history);
    final savedSurface = Map<String, String>.of(_surface);
    final savedNames = {...unregisteredNames};
    final savedSentence = _sentenceCounter, savedOrder = _order;
    try {
      final out = extract(
        'proposition',
        '${clause.trim().replaceAll(RegExp(r'[.?!]+$'), '')}.',
      );
      return out.facts.isEmpty ? null : out.facts.first;
    } finally {
      _history
        ..clear()
        ..addAll(savedHistory);
      _surface
        ..clear()
        ..addAll(savedSurface);
      unregisteredNames
        ..clear()
        ..addAll(savedNames);
      _sentenceCounter = savedSentence;
      _order = savedOrder;
    }
  }

  // ---- sentence level --------------------------------------------------------------

  void _sentence(_Work w) {
    final t = w.tokens;
    final quote = _quoteSpan(t);
    if (quote != null) {
      final (open, close) = quote;
      final speaker = _speakerOf(w, open, close);
      final inner = _trimPunct(t, open + 1, close);
      final attribution = Attribution(
        speaker: speaker.entityId,
        kind: 'reported',
      );
      _clauses(
        w,
        inner.$1,
        inner.$2,
        attribution: attribution,
        speaker: speaker.entityId,
      );
      return;
    }
    // "X said that ..." / "X believed that ..." / "X knew that ...": the main clause only
    // introduces. What kind of verb it is decides who the clause is attributed to.
    final thatAt = _complementAt(t);
    if (thatAt != null) {
      final (verbIdx, thatIdx, kind) = thatAt;
      final lemma = t[verbIdx].lemma ?? '';
      final speaker = _subjectBefore(w, verbIdx);
      final recipient = _registerNpsBetween(w, verbIdx + 1, thatIdx);
      final (negated, possible) = _mainFlags(t, verbIdx);
      // "Mara did not tell Iven that ...", "Mara might tell Iven that ...": nothing was
      // said, so the clause is not asserted by anyone. (A negated or hedged *knowing*
      // still presupposes the clause, so that kind goes on.)
      if ((negated || possible) && kind != 'factive') return;
      final before = w.facts.length;
      // The narrator also asserts what a character knew, saw or noticed; what was said
      // or read, believed or misremembered is the character's, not the narrator's.
      final attribution = switch (kind) {
        'factive' => null,
        'belief' || 'misremember' => Attribution(
          speaker: speaker?.entityId,
          kind: 'belief',
          verb: lemma,
        ),
        // Said or told: the speaker is the subject. Read or heard: the source is unknown.
        _ => Attribution(
          speaker: StoryLexicon.intakeVerbs.contains(lemma)
              ? null
              : speaker?.entityId,
          kind: 'reported',
          verb: lemma,
          recipient: recipient?.entityId,
        ),
      };
      _clauses(w, thatIdx + 1, _end(t), attribution: attribution);
      _cue(
        w,
        lemma,
        kind,
        speaker?.entityId,
        recipient?.entityId,
        negated,
        possible,
        before,
      );
      return;
    }
    // "X saw Mara hide the key": a perception verb, a noun phrase, a bare verb.
    final seen = _perceptionAt(w);
    if (seen != null) {
      final (verbIdx, clauseStart) = seen;
      final lemma = t[verbIdx].lemma ?? '';
      final knower = _subjectBefore(w, verbIdx);
      final (negated, possible) = _mainFlags(t, verbIdx);
      final before = w.facts.length;
      _clauses(w, clauseStart, _end(t));
      _cue(
        w,
        lemma,
        'perceived',
        knower?.entityId,
        null,
        negated,
        possible,
        before,
      );
      return;
    }
    _clauses(w, 0, _end(t));
  }

  int _end(List<Token> t) {
    var e = t.length;
    while (e > 0 && t[e - 1].pos == Upos.punct) {
      e--;
    }
    return e;
  }

  (int, int) _trimPunct(List<Token> t, int a, int b) {
    while (b > a && t[b - 1].pos == Upos.punct) {
      b--;
    }
    while (a < b && t[a].pos == Upos.punct) {
      a++;
    }
    return (a, b);
  }

  (int, int)? _quoteSpan(List<Token> t) {
    int? open;
    for (var i = 0; i < t.length; i++) {
      final x = t[i].text;
      if (open == null && (x == '"' || x == '“')) {
        open = i;
      } else if (open != null && (x == '"' || x == '”')) {
        return (open, i);
      }
    }
    return null;
  }

  /// Who is speaking around a quotation: the noun phrase beside the speech verb.
  _Ref _speakerOf(_Work w, int open, int close) {
    final t = w.tokens;
    int? verb;
    for (var i = 0; i < t.length; i++) {
      if (i > open && i < close) continue;
      if (t[i].pos == Upos.verb &&
          StoryLexicon.speechVerbs.contains(t[i].lemma)) {
        verb = i;
        break;
      }
    }
    if (verb == null) return const _Ref(null, '', unresolved: true);
    // Before the verb ("Iven said"), else after it ("said Mara").
    final before = _subjectBefore(w, verb);
    if (before != null && verb < open) return before;
    final after = _npAfter(w, verb + 1);
    if (after != null) return after;
    return before ?? const _Ref(null, '', unresolved: true);
  }

  /// The verb that introduces a "that" clause, the position of "that", and what kind of
  /// verb it is: `reported` (said, told, read, heard), `belief`, `factive` (knew,
  /// learned, saw that...), or `misremember`.
  (int, int, String)? _complementAt(List<Token> t) {
    for (var i = 0; i < t.length; i++) {
      if (t[i].pos == Upos.sconj && t[i].lower == 'that') {
        for (var k = i - 1; k >= 0 && k >= i - 4; k--) {
          if (t[k].pos == Upos.verb) {
            final lemma = t[k].lemma ?? '';
            final kind = lemma == 'misremember'
                ? 'misremember'
                : StoryLexicon.speechVerbs.contains(lemma) ||
                      StoryLexicon.intakeVerbs.contains(lemma)
                ? 'reported'
                : StoryLexicon.factiveVerbs.contains(lemma)
                ? 'factive'
                : StoryLexicon.beliefVerbs.contains(lemma)
                ? 'belief'
                : null;
            return kind == null ? null : (k, i, kind);
          }
        }
      }
    }
    return null;
  }

  /// "saw Mara hide the key": the perception verb and where the embedded clause starts.
  (int, int)? _perceptionAt(_Work w) {
    final t = w.tokens;
    for (var i = 0; i < t.length; i++) {
      if (t[i].pos != Upos.verb ||
          !StoryLexicon.perceptionVerbs.contains(t[i].lemma)) {
        continue;
      }
      final np = _np(w, i + 1, t.length);
      if (np == null || np.start != i + 1 || np.end >= t.length) continue;
      final next = t[np.end];
      if (next.pos == Upos.verb &&
          _lex.verbReadings(next.lower).any((e) => e.form == VerbForm.base)) {
        return (i, np.start);
      }
    }
    return null;
  }

  /// Negation and hedging on the verb at [verb]: "did not know", "might know".
  (bool, bool) _mainFlags(List<Token> t, int verb) {
    var negated = false, possible = false;
    var k = verb - 1;
    while (k >= 0 &&
        (t[k].pos == Upos.aux ||
            t[k].pos == Upos.adv ||
            t[k].pos == Upos.part)) {
      final lw = t[k].lower;
      if (lw == 'not' || lw == "n't" || lw == 'n\u2019t' || lw == 'never') {
        negated = true;
      }
      if (t[k].pos == Upos.aux &&
          (lw == 'might' || lw == 'may' || lw == 'could')) {
        possible = true;
      }
      if (lw == 'perhaps' || lw == 'maybe') possible = true;
      k--;
    }
    return (negated, possible);
  }

  void _cue(
    _Work w,
    String verb,
    String kind,
    String? knower,
    String? recipient,
    bool negated,
    bool possible,
    int factsBefore,
  ) {
    w.cues.add(
      KnowledgeCue(
        sourceId: w.sourceId,
        sentenceStart: w.sentence.start,
        sentenceEnd: w.sentence.end,
        verb: verb,
        kind: kind,
        factOrders: [for (final f in w.facts.skip(factsBefore)) f.order],
        knower: knower,
        recipient: recipient,
        negated: negated,
        possible: possible,
      ),
    );
  }

  /// Marks the noun phrases between [a] and [b] as recipients, and returns the first.
  _Ref? _registerNpsBetween(_Work w, int a, int b) {
    _Ref? first;
    var i = a;
    while (i < b) {
      final np = _np(w, i, b);
      if (np == null) {
        i++;
        continue;
      }
      final ref = _refOf(w, np, place: false);
      _mark(w, np, ref, SemanticRole.recipient);
      first ??= ref;
      i = np.end;
    }
    return first;
  }

  _Ref? _subjectBefore(_Work w, int verb) {
    final nps = _nps(w, 0, verb);
    if (nps.isEmpty) return null;
    final np = nps.last;
    final ref = _refOf(w, np, place: false);
    _mark(w, np, ref, SemanticRole.subject);
    return ref;
  }

  _Ref? _npAfter(_Work w, int from) {
    final np = _np(w, from, w.tokens.length);
    if (np == null) return null;
    final ref = _refOf(w, np, place: false);
    _mark(w, np, ref, SemanticRole.subject);
    return ref;
  }

  // ---- clauses ---------------------------------------------------------------------

  void _clauses(
    _Work w,
    int from,
    int to, {
    Attribution? attribution,
    String? speaker,
  }) {
    final t = w.tokens;
    // Split at "and"/"but"/"or" where a verb follows, then parse each part.
    final cuts = <int>[];
    for (var i = from + 1; i < to - 1; i++) {
      if (t[i].pos == Upos.cconj) {
        // The part before must be a clause too ("Edda and Iven carried it" is one
        // clause with two subjects, not two clauses).
        var leftHasVerb = false;
        for (var k = from; k < i; k++) {
          if (t[k].pos == Upos.verb ||
              (t[k].pos == Upos.aux &&
                  StoryLexicon.beForms.contains(t[k].lower))) {
            leftHasVerb = true;
            break;
          }
        }
        if (!leftHasVerb) continue;
        var hasVerb = false;
        for (var k = i + 1; k < to && t[k].pos != Upos.cconj; k++) {
          if (t[k].pos == Upos.verb ||
              (t[k].pos == Upos.aux &&
                  StoryLexicon.beForms.contains(t[k].lower))) {
            hasVerb = true;
            break;
          }
        }
        if (hasVerb) cuts.add(i);
      }
    }
    var a = from;
    _Ref? carried;
    for (final c in [...cuts, to]) {
      final end = c == to ? to : c;
      final subject = _clause(
        w,
        a,
        end,
        attribution: attribution,
        speaker: speaker,
        carried: carried,
      );
      carried = subject ?? carried;
      a = c + 1;
    }
  }

  List<_Np> _nps(_Work w, int from, int to) {
    final out = <_Np>[];
    var i = from;
    while (i < to) {
      final np = _np(w, i, to);
      if (np == null) {
        i++;
      } else {
        out.add(np);
        i = np.end;
      }
    }
    return out;
  }

  _Np? _np(_Work w, int i, int limit) {
    final t = w.tokens;
    if (i >= limit) return null;
    var j = i;
    final tok = t[j];
    if (tok.pos == Upos.propn) {
      while (j < limit && t[j].pos == Upos.propn) {
        j++;
      }
      // "Mara's key": the owner is dropped, the thing named is the noun phrase.
      if (j + 1 < limit && t[j].pos == Upos.part && t[j].text.contains("'") ||
          j + 1 < limit && t[j].pos == Upos.part && t[j].text.contains('’')) {
        final inner = _np(w, j + 1, limit);
        if (inner != null) {
          return _Np(
            start: i,
            end: inner.end,
            head: inner.head,
            nouns: inner.nouns,
            adjs: inner.adjs,
          );
        }
      }
      return _Np(start: i, end: j, head: j - 1, proper: true);
    }
    if (tok.pos == Upos.pron) {
      final lw = tok.lower;
      if (lw == 'who' ||
          lw == 'whom' ||
          lw == 'what' ||
          lw == 'there' ||
          lw == 'one') {
        return null;
      }
      return _Np(start: i, end: i + 1, head: i, pronoun: true);
    }
    if (tok.pos == Upos.det) j++;
    final adjs = <int>[];
    while (j < limit && (t[j].pos == Upos.adj || t[j].pos == Upos.num)) {
      adjs.add(j);
      j++;
    }
    final nouns = <int>[];
    while (j < limit && t[j].pos == Upos.noun) {
      nouns.add(j);
      j++;
    }
    if (nouns.isEmpty) return null;
    return _Np(start: i, end: j, head: j - 1, nouns: nouns, adjs: adjs);
  }

  // ---- references and coreference --------------------------------------------------

  _Ref _refOf(_Work w, _Np np, {required bool place, String? speaker}) {
    final t = w.tokens;
    final text = w.source.substring(t[np.start].start, t[np.end - 1].end);
    if (np.pronoun) {
      return _resolve(t[np.head].lower, text, speaker: speaker);
    }
    if (np.proper) {
      final words = [for (var k = np.start; k < np.end; k++) t[k].text];
      final known = registry.byName(words.first);
      if (known != null) return _Ref(known.id, text);
      final id = 'char_${words.map((x) => x.toLowerCase()).join('_')}';
      unregisteredNames.add(words.join(' '));
      return _Ref(id, text);
    }
    final lemmas = [for (final k in np.nouns) t[k].lemma ?? t[k].lower];
    final head = lemmas.last;
    if (!place && StoryLexicon.timeNouns.contains(head)) {
      return _Ref(null, text);
    }
    final type = place || StoryLexicon.placeNouns.contains(head)
        ? EntityType.place
        : StoryLexicon.personNouns.contains(head)
        ? EntityType.character
        : EntityType.item;
    return _Ref(EntityRegistry.idFor(type, lemmas), text);
  }

  _Ref _resolve(String word, String text, {String? speaker}) {
    final form = EntityRegistry.subjectForm(word);
    switch (form) {
      case 'i':
        return _Ref(
          speaker,
          _named(speaker, text),
          unresolved: speaker == null,
        );
      case 'she' || 'he' || 'they':
        final ids = <String>{};
        for (final m in _window()) {
          if (m.type == EntityType.character &&
              registry.byId(m.entityId)?.pronouns == form) {
            ids.add(m.entityId);
          }
        }
        return ids.length == 1
            ? _Ref(ids.first, _named(ids.first, text))
            : _Ref(null, text, unresolved: true);
      case 'it':
        final window = _window()
            .where((m) => m.type == EntityType.item)
            .toList();
        final ids = <String>{for (final m in window) m.entityId};
        if (ids.length == 1) return _Ref(ids.first, _named(ids.first, text));
        // More than one item: the one that was last the object of an action.
        final objects = <String>{
          for (final m in window)
            if (m.role == SemanticRole.object) m.entityId,
        };
        if (objects.length == 1) {
          return _Ref(objects.first, _named(objects.first, text));
        }
        return _Ref(null, text, unresolved: true);
      default:
        return _Ref(null, text, unresolved: true);
    }
  }

  String _named(String? id, String fallback) => id == null
      ? fallback
      : (_surface[id] ?? registry.byId(id)?.names.first ?? fallback);

  Iterable<_Mention> _window() =>
      _history.where((m) => m.sentence >= _sentenceCounter - 1);

  void _mark(_Work w, _Np np, _Ref ref, SemanticRole role) {
    final t = w.tokens;
    final id = ref.entityId;
    EntityType? type;
    if (id != null) {
      final prefix = id.split('_').first;
      type = EntityType.values.firstWhere(
        (e) => e.prefix == prefix,
        orElse: () => EntityType.other,
      );
      _history.add(_Mention(_sentenceCounter, id, type, role));
      if (!np.pronoun) {
        _surface[id] = registry.byId(id)?.names.first ?? ref.text;
      }
    }
    for (var k = np.start; k < np.end; k++) {
      final isContent =
          np.pronoun || np.proper || np.nouns.contains(k) || (k == np.head);
      if (isContent &&
          (t[k].pos == Upos.noun ||
              t[k].pos == Upos.propn ||
              t[k].pos == Upos.pron)) {
        t[k] = t[k].copyWith(role: role, entityId: id, entityType: type);
      }
    }
  }

  // ---- one clause ------------------------------------------------------------------

  /// Parses [from, to) as one clause and records its facts. Returns the subject so a
  /// coordinated predicate ("hid it and left") can share it.
  _Ref? _clause(
    _Work w,
    int from,
    int to, {
    Attribution? attribution,
    String? speaker,
    _Ref? carried,
  }) {
    final t = w.tokens;
    if (to - from < 2) return null;

    // The main verb: the first VERB that is not an infinitive ("to hide").
    int? v;
    for (var i = from; i < to; i++) {
      if (t[i].pos == Upos.verb &&
          !(i > from && t[i - 1].pos == Upos.part && t[i - 1].lower == 'to')) {
        v = i;
        break;
      }
    }
    // The first "be" is the verb of a copular clause.
    int? be;
    for (var i = from; i < to; i++) {
      if (t[i].pos == Upos.aux && StoryLexicon.beForms.contains(t[i].lower)) {
        be = i;
        break;
      }
    }
    final copular = v == null && be != null;
    if (v == null && !copular) return null;
    final anchor = (copular ? be : v)!;

    // The verb group: auxiliaries, negation and adverbs just before the verb.
    var groupStart = anchor;
    while (groupStart > from &&
        (t[groupStart - 1].pos == Upos.aux ||
            t[groupStart - 1].pos == Upos.adv ||
            t[groupStart - 1].pos == Upos.part)) {
      groupStart--;
    }
    var polarity = 'affirmed';
    var modality = 'certain';
    var passive = false;
    var hedged = false, conditional = false;
    for (var i = groupStart; i <= anchor; i++) {
      final lw = t[i].lower;
      if (lw == 'not' || lw == "n't" || lw == 'n’t' || lw == 'never') {
        polarity = 'negated';
      }
      if (t[i].pos == Upos.aux) {
        if (lw == 'might' || lw == 'may') hedged = true;
        if (lw == 'could' || lw == 'would') conditional = true;
      }
    }
    // "might hide" is a possibility. "could hide" is too, but "could not find" means
    // she did not, so a negated "could"/"would" is a negation, not a possibility.
    if (hedged || (conditional && polarity != 'negated')) modality = 'possible';
    for (var i = from; i < to; i++) {
      final lw = t[i].lower;
      if (lw == 'perhaps' ||
          lw == 'maybe' ||
          lw == 'possibly' ||
          lw == 'probably') {
        modality = 'possible';
      }
    }
    if (!copular) {
      // Passive: a form of "be" right before a participle, not a gerund.
      var k = anchor - 1;
      while (k >= from && (t[k].pos == Upos.adv || t[k].pos == Upos.part)) {
        k--;
      }
      final readings = _lex.verbReadings(t[anchor].lower);
      final gerundOnly =
          readings.isNotEmpty &&
          readings.every((e) => e.form == VerbForm.gerund);
      if (k >= from &&
          t[k].pos == Upos.aux &&
          StoryLexicon.beForms.contains(t[k].lower) &&
          !gerundOnly) {
        passive = true;
      }
    }

    final attributeFacts = <Fact>[];

    // Subject: the last noun phrase before the verb group that is not a PP complement.
    _Np? subjectNp;
    for (final np in _nps(w, from, groupStart)) {
      final before = np.start - 1;
      final inPp = before >= from && t[before].pos == Upos.adp;
      if (!inPp && np.end <= groupStart) subjectNp = np;
    }
    // "Edda and Iven carried it": every noun phrase joined by "and" is a subject.
    final subjectNps = <_Np>[?subjectNp];
    if (subjectNp != null) {
      var cur = subjectNp;
      while (true) {
        final cc = cur.start - 1;
        if (cc <= from || t[cc].pos != Upos.cconj || t[cc].lower != 'and') {
          break;
        }
        _Np? before;
        for (final np in _nps(w, from, cc)) {
          if (np.end == cc) before = np;
        }
        if (before == null) break;
        subjectNps.insert(0, before);
        cur = before;
      }
    }
    final subjectRefs = <_Ref>[];
    for (final np in subjectNps) {
      final r = _refOf(w, np, place: false, speaker: speaker);
      subjectRefs.add(r);
      _attributeFacts(w, np, r, attributeFacts, attribution);
    }
    _Ref? subject = subjectRefs.isEmpty ? carried : subjectRefs.last;

    // Manner and anything else between the subject and the verb, then complements.
    String? manner;
    for (var i = groupStart; i < anchor; i++) {
      if (_isManner(t[i])) {
        manner ??= t[i].lower;
        t[i] = t[i].copyWith(role: SemanticRole.manner);
      }
    }

    _Np? objectNp;
    final extraObjects = <_Np>[];
    _Np? recipientNp;
    _Ref? agent;
    SlotValue? location, destination, origin;
    String? time, attribute;
    var j = anchor + 1;
    var firstNp = true;
    // "took the key and the map": noun phrases joined by "and" are all objects.
    void absorbAnd() {
      while (j + 1 < to && t[j].pos == Upos.cconj && t[j].lower == 'and') {
        final n = _np(w, j + 1, to);
        if (n == null || n.start != j + 1) break;
        extraObjects.add(n);
        j = n.end;
      }
    }

    while (j < to) {
      final tok = t[j];
      if (tok.pos == Upos.cconj || tok.pos == Upos.sconj) break;
      if (tok.pos == Upos.adv && _isManner(tok)) {
        manner ??= tok.lower;
        t[j] = tok.copyWith(role: SemanticRole.manner);
        j++;
        continue;
      }
      if (tok.pos == Upos.adj &&
          (copular || (be != null && !passive && v == null))) {
        attribute ??= tok.lower;
        t[j] = tok.copyWith(role: SemanticRole.attribute);
        j++;
        continue;
      }
      if (tok.pos == Upos.adp) {
        final np = _np(w, j + 1, to);
        if (np == null || np.start != j + 1) {
          j++;
          continue;
        }
        final prep = tok.lower;
        final head = t[np.head];
        final isTimeNoun =
            StoryLexicon.timeNouns.contains(head.lemma ?? head.lower) ||
            StoryLexicon.weekdays.contains(head.lower);
        final span = w.source.substring(tok.start, t[np.end - 1].end);
        if (prep == 'by' && passive) {
          agent = _refOf(w, np, place: false, speaker: speaker);
          _mark(w, np, agent, SemanticRole.subject);
        } else if (StoryLexicon.timePrepositions.contains(prep) ||
            (StoryLexicon.locationPrepositions.contains(prep) && isTimeNoun) ||
            (prep == 'in' && isTimeNoun)) {
          time ??= span;
          t[j] = tok.copyWith(role: SemanticRole.time);
          for (var k = np.start; k < np.end; k++) {
            if (t[k].pos == Upos.noun || t[k].pos == Upos.propn) {
              t[k] = t[k].copyWith(role: SemanticRole.time);
            }
          }
        } else if (StoryLexicon.locationPrepositions.contains(prep) ||
            StoryLexicon.destinationPrepositions.contains(prep) ||
            StoryLexicon.originPrepositions.contains(prep)) {
          final ref = _refOf(w, np, place: true);
          final slot = SlotValue(text: span, entityId: ref.entityId);
          final role = StoryLexicon.destinationPrepositions.contains(prep)
              ? SemanticRole.location
              : StoryLexicon.originPrepositions.contains(prep)
              ? SemanticRole.source
              : SemanticRole.location;
          if (StoryLexicon.destinationPrepositions.contains(prep)) {
            destination ??= slot;
          } else if (StoryLexicon.originPrepositions.contains(prep)) {
            origin ??= slot;
          } else {
            location ??= slot;
          }
          _mark(w, np, ref, role);
          _attributeFacts(w, np, ref, attributeFacts, attribution);
        }
        j = np.end;
        continue;
      }
      final np = _np(w, j, to);
      if (np != null) {
        if (firstNp && !copular) {
          objectNp = np;
          firstNp = false;
          // Two noun phrases in a row after a giving verb: recipient, then object.
          final next = _np(w, np.end, to);
          if (next != null &&
              next.start == np.end &&
              StoryLexicon.ditransitiveVerbs.contains(t[anchor].lemma)) {
            recipientNp = np;
            objectNp = next;
            j = next.end;
            absorbAnd();
            continue;
          }
        } else if (copular && objectNp == null) {
          objectNp = np;
        }
        j = np.end;
        if (identical(objectNp, np)) absorbAnd();
        continue;
      }
      j++;
    }

    // Build the facts.
    final lemma = copular ? 'be' : (t[anchor].lemma ?? t[anchor].lower);
    final objectRefs = <_Ref>[];
    for (final np in [?objectNp, ...extraObjects]) {
      final r = _refOf(w, np, place: false);
      _mark(w, np, r, SemanticRole.object);
      _attributeFacts(w, np, r, attributeFacts, attribution);
      objectRefs.add(r);
    }
    SlotValue? recipient;
    if (recipientNp != null) {
      final r = _refOf(w, recipientNp, place: false);
      _mark(w, recipientNp, r, SemanticRole.recipient);
      recipient = SlotValue(text: r.text, entityId: r.entityId);
    }
    // "entered the hall": a place after a motion verb is where she went, not a thing.
    if (!passive &&
        !copular &&
        objectRefs.length == 1 &&
        (objectRefs.first.entityId ?? '').startsWith('place_')) {
      final place = objectRefs.first;
      final slot = SlotValue(text: place.text, entityId: place.entityId);
      if (StoryLexicon.enterVerbs.contains(lemma)) {
        destination ??= slot;
        objectRefs.clear();
      } else if (StoryLexicon.leaveVerbs.contains(lemma)) {
        origin ??= slot;
        objectRefs.clear();
      }
    }
    if (!copular) {
      t[anchor] = t[anchor].copyWith(role: SemanticRole.action);
    } else if (attribute == null && location == null && objectRefs.isEmpty) {
      return subject;
    }
    for (var k = 0; k < subjectNps.length; k++) {
      _mark(
        w,
        subjectNps[k],
        subjectRefs[k],
        passive ? SemanticRole.object : SemanticRole.subject,
      );
    }

    // Who acts and what is acted on. A passive clause's grammatical subject is the
    // thing acted on; the agent, if stated, is the one who acted.
    final actors = passive
        ? <_Ref?>[agent]
        : (subjectRefs.isEmpty ? <_Ref?>[carried] : <_Ref?>[...subjectRefs]);
    final targets = passive
        ? <_Ref?>[...subjectRefs]
        : (objectRefs.isEmpty ? <_Ref?>[null] : <_Ref?>[...objectRefs]);
    for (final actor in actors) {
      for (final target in targets) {
        final unresolved = actor?.unresolved ?? false;
        // A clause that identifies nobody says nothing usable.
        if (actor?.entityId == null &&
            target?.entityId == null &&
            !unresolved &&
            actor?.text == null &&
            target?.text == null) {
          continue;
        }
        w.facts.add(
          Fact(
            factId: '',
            sourceId: w.sourceId,
            order: _order++,
            sentenceStart: w.sentence.start,
            sentenceEnd: w.sentence.end,
            relation: lemma,
            subject: actor?.entityId,
            subjectText: actor?.text,
            object: target?.entityId,
            objectText: target?.text,
            location: location,
            destination: destination,
            origin: origin,
            recipient: recipient,
            time: time,
            manner: manner,
            attribute: attribute,
            polarity: polarity,
            modality: modality,
            attribution: attribution,
            unresolvedSubject: unresolved,
          ),
        );
      }
    }
    w.facts.addAll(attributeFacts);
    return subject;
  }

  bool _isManner(Token t) =>
      t.pos == Upos.adv &&
      t.lower.endsWith('ly') &&
      t.lower.length > 4 &&
      !StoryLexicon.sentenceAdverbs.contains(t.lower);

  /// "The silver key": a colour or material before a noun is a fact about it.
  void _attributeFacts(
    _Work w,
    _Np np,
    _Ref ref,
    List<Fact> into,
    Attribution? attribution,
  ) {
    final id = ref.entityId;
    if (id == null || np.proper || np.pronoun) return;
    for (final k in np.adjs) {
      final adj = w.tokens[k];
      if (StoryLexicon.colours.contains(adj.lower) ||
          StoryLexicon.materials.contains(adj.lower)) {
        w.tokens[k] = adj.copyWith(role: SemanticRole.attribute);
        into.add(
          Fact(
            factId: '',
            sourceId: w.sourceId,
            order: _order++,
            sentenceStart: w.sentence.start,
            sentenceEnd: w.sentence.end,
            relation: 'be',
            subject: id,
            subjectText: ref.text,
            attribute: adj.lower,
            attribution: attribution,
          ),
        );
      }
    }
  }
}

class _Work {
  _Work(this.sourceId, this.source, this.sentence)
    : tokens = List<Token>.of(sentence.tokens);
  final String sourceId;
  final String source;
  final Sentence sentence;
  final List<Token> tokens;
  final facts = <Fact>[];
  final cues = <KnowledgeCue>[];
}
