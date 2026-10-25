/// Character Knowledge Continuity: what a character knows, believes, suspects or has
/// wrong at a point in the story, how the information reached them, and the exact
/// words that say so.
///
/// Built from sentences that report what a character took in ("Mara told Iven that she
/// hid the key", "Edda watched Mara hide it", "Iven did not know that ..."). It is a
/// *derived index*: every event points at a source passage (or an author record) and
/// the whole thing is rebuilt from them, so it can never disagree with the text it came
/// from and is never a second source of truth.
///
/// Rules that keep it honest:
///  * being told something is not knowing it: a character who was told a claim the
///    narrator does not confirm BELIEVES it, and one told something the narrator
///    confirms KNOWS it;
///  * no record is not ignorance: with no acquisition on file the answer is UNKNOWN
///    ("no recorded acquisition found"), never "does not know";
///  * a character's belief stays separate from what the story says is true
///    (`matchesCanon`), so a false belief is a belief and not a contradiction;
///  * a knowledge leak is a *review item* with both passages and the timeline order, not
///    a declared error.
// ignore_for_file: prefer_initializing_formals
library;

import 'facts.dart';
import 'labels.dart';
import 'lexicon.dart';

// ---- labels ------------------------------------------------------------------------

enum KnowledgeState {
  knows('KNOWS'),
  believes('BELIEVES'),
  suspects('SUSPECTS'),
  misremembers('MISREMEMBERS'),

  /// The author recorded that the character does not know it yet.
  authorConfirmedUnaware('AUTHOR_CONFIRMED_UNAWARE'),

  /// The text itself says the character did not know ("Iven did not know that ...").
  /// An addition to the handover's list, so a passage that says so is not forced into
  /// the author-entered state; confirm or fold into `AUTHOR_CONFIRMED_UNAWARE`.
  unawareInText('UNAWARE_IN_TEXT');

  const KnowledgeState(this.label);
  final String label;

  bool get isUnaware => this == authorConfirmedUnaware || this == unawareInText;

  static KnowledgeState? parse(String label) {
    for (final s in values) {
      if (s.label == label) return s;
    }
    return null;
  }
}

enum AcquisitionRoute {
  witnessed('WITNESSED'),
  told('TOLD'),
  overheard('OVERHEARD'),
  read('READ'),
  experienced('EXPERIENCED'),
  inferred('INFERRED'),
  authorEntered('AUTHOR_ENTERED');

  const AcquisitionRoute(this.label);
  final String label;

  static AcquisitionRoute? parse(String label) {
    for (final r in values) {
      if (r.label == label) return r;
    }
    return null;
  }
}

// ---- propositions ------------------------------------------------------------------

/// The story fact a character may know. Two propositions are the same when they have
/// the same canonical verb, subject and object; for a state ("the key was under the
/// pier") the place or attribute is part of it, because "under the pier" and "in the
/// barn" are different things to know.
class Proposition {
  const Proposition({
    required this.relation,
    this.subject,
    this.object,
    this.location,
    this.attribute,
    this.polarity = 'affirmed',
  });

  factory Proposition.fromFact(Fact f) => Proposition(
    relation: canonicalRelation(f.relation),
    subject: f.subject,
    object: f.object,
    location: f.location?.entityId,
    attribute: f.attribute,
    polarity: f.polarity,
  );

  /// The first word of the verb's synonym group, so `conceal` and `hide` meet.
  static String canonicalRelation(String lemma) {
    for (final g in StoryLexicon.synonymGroups) {
      if (g.contains(lemma)) return g.first;
    }
    return lemma;
  }

  final String relation;
  final String? subject;
  final String? object;
  final String? location;
  final String? attribute;
  final String polarity;

  bool get isState => relation == 'be';

  /// Whether a stored proposition [other] is what this (asked-for) one means.
  /// A missing subject or object in this one matches anything.
  bool matches(Proposition other) {
    if (relation != other.relation) return false;
    if (subject != null && !sameEntity(subject, other.subject)) return false;
    if (object != null && !sameEntity(object, other.object)) return false;
    if (isState) {
      if (location != null && !sameEntity(location, other.location)) {
        return false;
      }
      if (attribute != null && attribute != other.attribute) return false;
    }
    return true;
  }

  /// Used to link a later belief or revelation to the one it replaces.
  String get groupKey => '$relation|$subject|$object';

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'relation': relation,
    'object': object,
    if (location != null) 'location': location,
    if (attribute != null) 'attribute': attribute,
    'polarity': polarity,
  };
}

// ---- timeline ----------------------------------------------------------------------

class TimelineEntry {
  const TimelineEntry(this.id, this.label);
  final String id;
  final String label;
}

/// Story order: the places a passage can sit. Chapter and scene are just entries
/// whose ids share a prefix (`chapter_02`, `chapter_02_scene_04`); "by Chapter 2" is the
/// end of everything under `chapter_02`. Where an application already keeps story time
/// (a Timeline or scene order), it supplies these ids and this holds no authority.
class StoryTimeline {
  StoryTimeline([Iterable<TimelineEntry> entries = const []]) {
    for (final e in entries) {
      add(e.id, e.label);
    }
  }

  final _entries = <TimelineEntry>[];
  List<TimelineEntry> get entries => List.unmodifiable(_entries);

  /// Adds a point at the end of the story so far and returns its position.
  /// An id already there keeps its place.
  int add(String id, [String? label]) {
    final at = position(id);
    if (at != null) return at;
    _entries.add(TimelineEntry(id, label ?? _readable(id)));
    return _entries.length - 1;
  }

  int? position(String id) {
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].id == id) return i;
    }
    return null;
  }

  int get endPosition => _entries.length - 1;

  /// The last position at or under [id]: `chapter_02` is the end of its scenes.
  int? endOf(String id) {
    int? at;
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].id == id || _entries[i].id.startsWith('${id}_')) at = i;
    }
    return at;
  }

  /// `chapter_02_scene_04` as "Chapter 2, Scene 4"; any other id as it is.
  static String _readable(String id) {
    final parts = id.split('_');
    if (parts.length < 2 || parts.length.isOdd) return id;
    final out = <String>[];
    for (var i = 0; i < parts.length; i += 2) {
      final n = int.tryParse(parts[i + 1]);
      if (n == null || parts[i].isEmpty) return id;
      out.add('${parts[i][0].toUpperCase()}${parts[i].substring(1)} $n');
    }
    return out.join(', ');
  }

  /// Lower case, punctuation as spaces, and numbers without leading zeros, so
  /// "Chapter 03" and "chapter 3" are the same.
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAllMapped(RegExp(r'\b0+(\d)'), (m) => m[1]!)
      .trim();

  /// "Chapter 3" or "chapter 2, scene 1" to the end position it names, or null.
  int? resolveLabel(String text) {
    final q = _norm(text);
    if (q.isEmpty) return null;
    int? at;
    for (var i = 0; i < _entries.length; i++) {
      for (final name in [_norm(_entries[i].label), _norm(_entries[i].id)]) {
        if (name == q || name.startsWith('$q ')) at = i;
      }
    }
    return at;
  }

  String? idAt(int position) => position >= 0 && position < _entries.length
      ? _entries[position].id
      : null;
}

// ---- events ------------------------------------------------------------------------

class KnowledgeEvent {
  KnowledgeEvent({
    required this.id,
    required this.characterId,
    required this.proposition,
    required this.state,
    required this.route,
    required this.storyTimeId,
    required this.evidence,
    required this.order,
    this.possible = false,
  });

  final String id;
  final String characterId;
  final Proposition proposition;
  final KnowledgeState state;

  /// Null when the text does not say how ("Iven believed that ...").
  final AcquisitionRoute? route;
  final String storyTimeId;
  final EvidenceRef evidence;

  /// Reading order, to settle events at the same story time.
  final int order;

  /// A hedged cue ("might know"): kept so it can be reported, never used as knowledge.
  final bool possible;

  /// The earlier event this one corrects or replaces, and when this one stops applying.
  String? supersedes;
  String? validUntil;

  String get sourceId => evidence.sourceId;

  Map<String, dynamic> toJson() => {
    'event_id': id,
    'character_id': characterId,
    'proposition': proposition.toJson(),
    'knowledge_state': state.label,
    'acquisition_route': route?.label,
    'story_time_id': storyTimeId,
    'evidence_refs': [evidence.sourceId],
    'status': EvidenceStatus.stated.label,
    if (possible) 'modality': 'possible',
    if (supersedes != null) 'supersedes': supersedes,
    if (validUntil != null) 'valid_until': validUntil,
  };
}

/// What the author recorded about a character's knowledge: the authority for states the
/// text does not say, such as "Lucia does not know yet".
class AuthorKnowledgeRecord {
  const AuthorKnowledgeRecord({
    required this.recordId,
    required this.characterId,
    required this.storyTimeId,
    required this.state,
    required this.text,
    this.note,
  });

  final String recordId;
  final String characterId;
  final String storyTimeId;
  final KnowledgeState state;

  /// The proposition, as a sentence: "Mara hid the key."
  final String text;
  final String? note;
}

// ---- answers -----------------------------------------------------------------------

class KnowledgeAnswer {
  const KnowledgeAnswer({
    required this.kind,
    required this.status,
    this.state,
    this.route,
    this.who = const [],
    this.storyTimeId,
    this.evidence = const [],
    this.matchesCanon,
    this.note,
    this.trace = const [],
  });

  /// `knows`, `who_knows`, `when_learned`.
  final String kind;

  /// STATED, UNKNOWN or CONFLICT. A missing record is UNKNOWN, never "does not know".
  final EvidenceStatus status;
  final KnowledgeState? state;
  final AcquisitionRoute? route;
  final List<String> who;

  /// For `when_learned`: where the character learned it.
  final String? storyTimeId;
  final List<EvidenceRef> evidence;

  /// Whether the story itself says it is true: true, false (the story says otherwise)
  /// or null (the story does not say). A belief can be false without being a conflict.
  final bool? matchesCanon;
  final String? note;
  final List<String> trace;

  Set<String> get evidenceSourceIds => {for (final e in evidence) e.sourceId};

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'status': status.label,
    'knowledge_state': state?.label,
    'acquisition_route': route?.label,
    'who': who,
    'story_time_id': storyTimeId,
    'evidence': [for (final e in evidence) e.toJson()],
    'matches_canon': matchesCanon,
    'note': note,
  };
}

/// A possible knowledge leak, for the author to look at. Not an error: flashbacks,
/// an unreliable narrator or an intended reveal could explain it.
class KnowledgeLeakReview {
  const KnowledgeLeakReview({
    required this.characterId,
    required this.action,
    required this.proposition,
    required this.actionTimeId,
    required this.propositionTimeId,
    this.acquisition,
    this.acquisitionTimeId,
    required this.reason,
  });

  final String characterId;

  /// The passage where the character acts on the fact.
  final EvidenceRef action;

  /// The passage that establishes the fact.
  final EvidenceRef proposition;
  final String actionTimeId;
  final String propositionTimeId;

  /// The character's first recorded acquisition, if any (later than the action).
  final EvidenceRef? acquisition;
  final String? acquisitionTimeId;
  final String reason;

  Map<String, dynamic> toJson() => {
    'character_id': characterId,
    'action_source_id': action.sourceId,
    'proposition_source_id': proposition.sourceId,
    'acquisition_source_id': acquisition?.sourceId,
    'timeline_order': [propositionTimeId, actionTimeId, ?acquisitionTimeId],
    'reason': reason,
  };
}

// ---- the index ---------------------------------------------------------------------

/// Evidence for a span of a source, built by the caller that owns the source texts.
typedef EvidenceAt = EvidenceRef Function(String sourceId, int start, int end);

class KnowledgeIndex {
  KnowledgeIndex({
    required List<Fact> facts,
    required List<KnowledgeCue> cues,
    required Map<String, String> sourceTimes,
    required this.timeline,
    required EvidenceAt evidenceAt,
    List<AuthorKnowledgeRecord> authorRecords = const [],
    Proposition? Function(String text)? propositionOf,
  }) : _facts = facts,
       _evidenceAt = evidenceAt,
       _times = sourceTimes {
    _build(cues, sourceTimes, authorRecords, propositionOf);
  }

  final List<Fact> _facts;
  final EvidenceAt _evidenceAt;
  final Map<String, String> _times;
  final StoryTimeline timeline;
  final _events = <KnowledgeEvent>[];
  final _embedded = <int>{};

  List<KnowledgeEvent> get events => List.unmodifiable(_events);

  static const _believeVerbs = {
    'believe',
    'think',
    'suppose',
    'assume',
    'imagine',
    'fancy',
    'guess',
    'feel',
  };

  // ---- building ---------------------------------------------------------------------

  void _build(
    List<KnowledgeCue> cues,
    Map<String, String> times,
    List<AuthorKnowledgeRecord> author,
    Proposition? Function(String text)? propositionOf,
  ) {
    final byOrder = {for (final f in _facts) f.order: f};
    for (final c in cues) {
      _embedded.addAll(c.factOrders);
    }
    var n = 0;
    void add(
      String character,
      Proposition p,
      KnowledgeState state,
      AcquisitionRoute? route,
      String timeId,
      EvidenceRef ev,
      int order, {
      bool possible = false,
    }) {
      n++;
      _events.add(
        KnowledgeEvent(
          id: 'ke_$n',
          characterId: character,
          proposition: p,
          state: state,
          route: route,
          storyTimeId: timeId,
          evidence: ev,
          order: order,
          possible: possible,
        ),
      );
    }

    for (final c in cues) {
      final first = c.factOrders.isEmpty ? null : byOrder[c.factOrders.first];
      final timeId = times[c.sourceId];
      if (first == null || timeId == null) continue;
      final p = Proposition.fromFact(first);
      final ev = _evidenceAt(c.sourceId, c.sentenceStart, c.sentenceEnd);
      final confirmed = canonStatus(p);
      // What the narrator confirms is known to someone told it; what they do not
      // confirm, or contradict, is only believed.
      final told = confirmed == true
          ? KnowledgeState.knows
          : KnowledgeState.believes;
      final order = first.order;
      switch (c.kind) {
        case 'reported':
          if (StoryLexicon.intakeVerbs.contains(c.verb)) {
            final who = c.knower;
            if (who != null) {
              add(
                who,
                p,
                told,
                c.verb == 'read'
                    ? AcquisitionRoute.read
                    : AcquisitionRoute.overheard,
                timeId,
                ev,
                order,
                possible: c.possible,
              );
            }
          } else {
            final who = c.recipient;
            if (who != null && who.startsWith('char_')) {
              add(who, p, told, AcquisitionRoute.told, timeId, ev, order);
            }
          }
        case 'belief':
          final who = c.knower;
          if (who == null || c.negated) break;
          if (c.verb == 'suspect') {
            add(
              who,
              p,
              KnowledgeState.suspects,
              AcquisitionRoute.inferred,
              timeId,
              ev,
              order,
              possible: c.possible,
            );
          } else if (_believeVerbs.contains(c.verb)) {
            add(
              who,
              p,
              KnowledgeState.believes,
              null,
              timeId,
              ev,
              order,
              possible: c.possible,
            );
          }
        case 'misremember':
          final who = c.knower;
          if (who != null && !c.negated) {
            add(
              who,
              p,
              KnowledgeState.misremembers,
              null,
              timeId,
              ev,
              order,
              possible: c.possible,
            );
          }
        case 'factive' || 'perceived':
          final who = c.knower;
          if (who == null) break;
          final route = switch (c.verb) {
            'see' ||
            'watch' ||
            'notice' ||
            'witness' => AcquisitionRoute.witnessed,
            'hear' || 'overhear' => AcquisitionRoute.overheard,
            'realize' ||
            'realise' ||
            'understand' ||
            'deduce' ||
            'infer' => AcquisitionRoute.inferred,
            _ => null,
          };
          if (c.negated) {
            add(who, p, KnowledgeState.unawareInText, null, timeId, ev, order);
          } else {
            add(
              who,
              p,
              KnowledgeState.knows,
              route,
              timeId,
              ev,
              order,
              possible: c.possible,
            );
          }
      }
    }

    // A character who does something on purpose knows they did it.
    for (final f in _facts) {
      final who = f.subject;
      final timeId = times[f.sourceId];
      if (who == null ||
          !who.startsWith('char_') ||
          timeId == null ||
          f.attribution != null ||
          _embedded.contains(f.order) ||
          f.relation == 'be' ||
          f.polarity != 'affirmed' ||
          f.modality != 'certain') {
        continue;
      }
      add(
        who,
        Proposition.fromFact(f),
        KnowledgeState.knows,
        AcquisitionRoute.experienced,
        timeId,
        _evidenceAt(f.sourceId, f.sentenceStart, f.sentenceEnd),
        f.order,
      );
    }

    // What the author recorded.
    for (final a in author) {
      final p = propositionOf?.call(a.text);
      if (p == null) continue;
      final quote = a.note ?? a.text;
      add(
        a.characterId,
        p,
        a.state,
        AcquisitionRoute.authorEntered,
        a.storyTimeId,
        EvidenceRef(
          sourceId: a.recordId,
          start: 0,
          end: quote.length,
          quote: quote,
          kind: 'author_record',
        ),
        -1,
      );
    }

    // Link a later change of belief or state to what it replaces.
    final groups = <String, List<KnowledgeEvent>>{};
    for (final e in _events.where((e) => !e.possible)) {
      groups
          .putIfAbsent('${e.characterId}|${e.proposition.groupKey}', () => [])
          .add(e);
    }
    for (final g in groups.values) {
      g.sort(_byTime);
      for (var i = 1; i < g.length; i++) {
        final prev = g[i - 1], cur = g[i];
        if (prev.state != cur.state ||
            prev.proposition.key != cur.proposition.key) {
          cur.supersedes = prev.id;
          prev.validUntil = cur.storyTimeId;
        }
      }
    }
  }

  int _pos(KnowledgeEvent e) => timeline.position(e.storyTimeId) ?? -1;

  int _byTime(KnowledgeEvent a, KnowledgeEvent b) {
    final c = _pos(a).compareTo(_pos(b));
    return c != 0 ? c : a.order.compareTo(b.order);
  }

  // ---- what the story itself says ---------------------------------------------------

  /// Whether the narrator says [p] is true (true), says it is not (false), or does not
  /// say (null). Only the narrator's own statements count, never a character's claim.
  bool? canonStatus(Proposition p) {
    var yes = false, no = false;
    for (final f in _facts) {
      if (f.attribution != null || f.modality != 'certain') continue;
      final q = Proposition.fromFact(f);
      if (p.relation != q.relation ||
          !_same(p.subject, q.subject) ||
          !_same(p.object, q.object)) {
        continue;
      }
      if (p.isState) {
        final differs =
            (p.location != null &&
                q.location != null &&
                !sameEntity(p.location, q.location)) ||
            (p.attribute != null &&
                q.attribute != null &&
                p.attribute != q.attribute);
        if (differs && f.polarity == 'affirmed') {
          no = true;
          continue;
        }
        if ((p.location != null && !sameEntity(p.location, q.location)) ||
            (p.attribute != null && p.attribute != q.attribute)) {
          continue;
        }
      }
      if (f.polarity == 'affirmed') {
        yes = true;
      } else {
        no = true;
      }
    }
    if (yes && no) return null;
    return yes ? true : (no ? false : null);
  }

  /// Both missing counts as the same ("the key was in the barn" has no object).
  static bool _same(String? a, String? b) =>
      (a == null && b == null) || sameEntity(a, b);

  // ---- queries ----------------------------------------------------------------------

  int _at(String? timeId) => timeId == null
      ? timeline.endPosition
      : (timeline.endOf(timeId) ?? timeline.endPosition);

  /// What [characterId] knows about [p] at the end of [at] (the end of the story if
  /// null). The answer is the state the character is in then, where it came from, and
  /// the passage that put them in it.
  KnowledgeAnswer knowsAt(String characterId, Proposition p, {String? at}) {
    final trace = <String>[
      'character $characterId',
      'point ${at ?? 'end of story'}',
    ];
    final limit = _at(at);
    final mine =
        _events
            .where(
              (e) => e.characterId == characterId && p.matches(e.proposition),
            )
            .toList()
          ..sort(_byTime);
    final certain = mine.where((e) => !e.possible).toList();
    final upTo = certain.where((e) => _pos(e) <= limit).toList();
    trace.add(
      '${mine.length} event(s) for this character and proposition, ${upTo.length} by then',
    );
    if (upTo.isEmpty) {
      final later = certain.where((e) => _pos(e) > limit).toList();
      if (later.isNotEmpty) {
        return KnowledgeAnswer(
          kind: 'knows',
          status: EvidenceStatus.unknown,
          note: 'first recorded acquisition is later',
          evidence: [later.first.evidence],
          trace: trace,
        );
      }
      final hedged = mine.where((e) => e.possible && _pos(e) <= limit).toList();
      if (hedged.isNotEmpty) {
        return KnowledgeAnswer(
          kind: 'knows',
          status: EvidenceStatus.unknown,
          note: 'possibility only',
          evidence: [for (final e in hedged) e.evidence],
          trace: trace,
        );
      }
      return KnowledgeAnswer(
        kind: 'knows',
        status: EvidenceStatus.unknown,
        note: 'no recorded acquisition found',
        trace: trace,
      );
    }
    // Two passages at the same moment that disagree about awareness clash.
    final lastPos = _pos(upTo.last);
    final atLast = upTo.where((e) => _pos(e) == lastPos).toList();
    final aware = atLast.any((e) => !e.state.isUnaware);
    final unaware = atLast.any((e) => e.state.isUnaware);
    if (aware && unaware) {
      return KnowledgeAnswer(
        kind: 'knows',
        status: EvidenceStatus.conflict,
        evidence: [for (final e in atLast) e.evidence],
        trace: trace,
      );
    }
    // The event that started the state the character is in now.
    var start = upTo.length - 1;
    while (start > 0 && upTo[start - 1].state == upTo.last.state) {
      start--;
    }
    final decider = upTo[start];
    return KnowledgeAnswer(
      kind: 'knows',
      status: EvidenceStatus.stated,
      state: upTo.last.state,
      route: decider.route,
      evidence: [decider.evidence],
      matchesCanon: canonStatus(p),
      trace: trace,
    );
  }

  /// Everyone who knows [p] at the end of [at].
  KnowledgeAnswer whoKnows(Proposition p, {String? at}) {
    final characters = {
      for (final e in _events)
        if (p.matches(e.proposition)) e.characterId,
    };
    final who = <String>[];
    final evidence = <EvidenceRef>[];
    for (final c in characters) {
      final a = knowsAt(c, p, at: at);
      if (a.status == EvidenceStatus.stated &&
          a.state == KnowledgeState.knows) {
        who.add(c);
        evidence.addAll(a.evidence);
      }
    }
    if (who.isEmpty) {
      return KnowledgeAnswer(
        kind: 'who_knows',
        status: EvidenceStatus.unknown,
        note: 'no recorded acquisition found',
        trace: [
          '${characters.length} character(s) have a record, none of them knows it',
        ],
      );
    }
    return KnowledgeAnswer(
      kind: 'who_knows',
      status: EvidenceStatus.stated,
      who: who,
      evidence: evidence,
      matchesCanon: canonStatus(p),
    );
  }

  /// Where [characterId] first came to know [p].
  KnowledgeAnswer whenLearned(String characterId, Proposition p) {
    final mine =
        _events
            .where(
              (e) =>
                  e.characterId == characterId &&
                  !e.possible &&
                  e.state == KnowledgeState.knows &&
                  p.matches(e.proposition),
            )
            .toList()
          ..sort(_byTime);
    if (mine.isEmpty) {
      return const KnowledgeAnswer(
        kind: 'when_learned',
        status: EvidenceStatus.unknown,
        note: 'no recorded acquisition found',
      );
    }
    final first = mine.first;
    return KnowledgeAnswer(
      kind: 'when_learned',
      status: EvidenceStatus.stated,
      state: first.state,
      route: first.route,
      storyTimeId: first.storyTimeId,
      evidence: [first.evidence],
      matchesCanon: canonStatus(p),
    );
  }

  // ---- possible knowledge leaks -----------------------------------------------------

  /// A character acts on something that was hidden or placed, before any recorded
  /// moment at which they learned of it. One pattern is checked, the one the handover
  /// describes ("acts on a fact before a recorded acquisition event"): a hiding or
  /// placement the narrator states, and a later action by someone else on the same
  /// object or place. Each hit is a review item; nothing is rewritten or declared wrong.
  List<KnowledgeLeakReview> leaks() {
    final out = <KnowledgeLeakReview>[];
    for (final p in _facts) {
      if (p.attribution != null ||
          _embedded.contains(p.order) ||
          p.polarity != 'affirmed' ||
          p.modality != 'certain' ||
          p.subject == null ||
          !StoryLexicon.instance
              .synonyms(p.relation)
              .intersection(StoryLexicon.placementVerbs)
              .isNotEmpty) {
        continue;
      }
      final place = p.location?.entityId ?? p.destination?.entityId;
      if (place == null && p.object == null) continue;
      final pTime = _timeOfFact(p);
      if (pTime == null) continue;
      final pProp = Proposition.fromFact(p);
      for (final a in _facts) {
        if (identical(a, p) ||
            a.attribution != null ||
            _embedded.contains(a.order) ||
            a.polarity != 'affirmed' ||
            a.modality != 'certain' ||
            a.subject == null ||
            !a.subject!.startsWith('char_') ||
            sameEntity(a.subject, p.subject) ||
            sameEntity(a.subject, p.recipient?.entityId)) {
          continue;
        }
        final touches = [
          a.object,
          a.location?.entityId,
          a.destination?.entityId,
          a.origin?.entityId,
        ];
        final sharesPlace =
            place != null && touches.any((t) => sameEntity(t, place));
        final sharesThing =
            p.object != null && touches.any((t) => sameEntity(t, p.object));
        if (!sharesPlace && !sharesThing) continue;
        final aTime = _timeOfFact(a);
        if (aTime == null) continue;
        final ap = timeline.position(aTime) ?? -1,
            pp = timeline.position(pTime) ?? -1;
        if (ap < pp || (ap == pp && a.order <= p.order)) continue;
        final known =
            _events
                .where(
                  (e) =>
                      e.characterId == a.subject &&
                      !e.possible &&
                      !e.state.isUnaware &&
                      pProp.matches(e.proposition) &&
                      e.proposition.relation == pProp.relation,
                )
                .toList()
              ..sort(_byTime);
        final before = known.any(
          (e) => _pos(e) < ap || (_pos(e) == ap && e.order < a.order),
        );
        if (before) continue;
        final later = known.where((e) => _pos(e) >= ap).toList();
        out.add(
          KnowledgeLeakReview(
            characterId: a.subject!,
            action: _evidenceAt(a.sourceId, a.sentenceStart, a.sentenceEnd),
            proposition: _evidenceAt(
              p.sourceId,
              p.sentenceStart,
              p.sentenceEnd,
            ),
            actionTimeId: aTime,
            propositionTimeId: pTime,
            acquisition: later.isEmpty ? null : later.first.evidence,
            acquisitionTimeId: later.isEmpty ? null : later.first.storyTimeId,
            reason: later.isEmpty
                ? 'No recorded moment at which this character learns it.'
                : 'The character is recorded learning it only later.',
          ),
        );
      }
    }
    return out;
  }

  String? _timeOfFact(Fact f) => _times[f.sourceId];
}

extension on Proposition {
  /// The full identity of a proposition, used to tell a changed belief from a repeat.
  String get key => '$relation|$subject|$object|$location|$attribute';
}
