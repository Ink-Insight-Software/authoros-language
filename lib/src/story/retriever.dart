/// Answers a parsed question from the facts, and says how the answer is known.
///
/// Deterministic: the same facts and question always give the same answer. Nothing
/// here writes to the story, and nothing here guesses; where the story is silent the
/// answer is UNKNOWN, and where two passages disagree it is CONFLICT with both.
///
/// Policy, in order:
///  * only the narrator's own statements count when there are any; what a character
///    said or believed is used only when nothing else answers, and is labelled so;
///  * a negated fact answers "did X?" with No and is never evidence for "where";
///  * a possibility ("might") answers nothing but is reported as such;
///  * a place stated by "the key was in X" is STATED; one worked out from "she hid
///    the key in X" is DERIVED, and a later action that moves the thing makes it
///    UNKNOWN rather than a guess;
///  * two passages that disagree are CONFLICT, never resolved silently.
library;

import 'answer.dart';
import 'facts.dart';
import 'labels.dart';
import 'lexicon.dart';
import 'question.dart';

class StoryRetriever {
  const StoryRetriever();
  static final _lex = StoryLexicon.instance;

  static const _stative = {
    'be',
    'stand',
    'sit',
    'lie',
    'live',
    'wait',
    'stay',
    'remain',
    'hang',
    'rest',
  };

  Answer answer(
    StoryQuestion q,
    List<Fact> facts,
    EvidenceRef Function(Fact) refOf,
  ) {
    final trace = <String>[
      'intent ${q.intent.label}',
      'relation ${q.relation}',
      'entities ${q.entities}',
    ];
    Answer unknown({
      String? note,
      List<Fact> evidence = const [],
      bool offer = false,
    }) => Answer(
      question: q,
      status: EvidenceStatus.unknown,
      note: note,
      evidence: _refs(evidence, refOf),
      offerProposal: offer,
      trace: trace,
    );

    if (q.intent == QuestionIntent.unsupported || q.entities.isEmpty) {
      trace.add('nothing to look up');
      return unknown(
        note: q.intent == QuestionIntent.unsupported
            ? 'question not understood'
            : null,
      );
    }

    final verbs = q.relation == null ? null : _lex.synonyms(q.relation!);
    bool relationOk(Fact f) => verbs == null || verbs.contains(f.relation);

    switch (q.intent) {
      case QuestionIntent.location when q.relation == null:
        return _whereIs(q, facts, refOf, trace);
      case QuestionIntent.attribute:
        return _attribute(q, facts, refOf, trace);
      default:
    }

    // Facts about the asked thing and verb.
    final about = [
      for (final f in facts)
        if (relationOk(f) && _participates(q, f)) f,
    ];
    trace.add('${about.length} fact(s) match the verb and entities');
    final narrator = about.where((f) => f.attribution == null).toList();
    final pool = narrator.isNotEmpty ? narrator : about;
    final certain = pool.where((f) => f.modality == 'certain').toList();
    final affirmed = certain.where((f) => f.polarity == 'affirmed').toList();
    final negated = certain.where((f) => f.polarity == 'negated').toList();
    final possible = pool.where((f) => f.modality != 'certain').toList();

    if (q.intent == QuestionIntent.yesNo) {
      if (affirmed.isNotEmpty && negated.isNotEmpty) {
        return Answer(
          question: q,
          status: EvidenceStatus.conflict,
          answers: const ['Yes', 'No'],
          evidence: _refs([...affirmed, ...negated], refOf),
          trace: trace,
        );
      }
      if (affirmed.isNotEmpty) return _stated(q, 'Yes', affirmed, refOf, trace);
      if (negated.isNotEmpty) return _stated(q, 'No', negated, refOf, trace);
      if (possible.isNotEmpty) {
        return unknown(note: 'possibility only', evidence: possible);
      }
      return unknown(offer: true);
    }

    if (affirmed.isEmpty) {
      if (possible.isNotEmpty) {
        return unknown(note: 'possibility only', evidence: possible);
      }
      return unknown(offer: true);
    }

    switch (q.intent) {
      case QuestionIntent.location:
        return _pick(
          q,
          affirmed,
          (f) => (f.location ?? f.destination)?.text,
          refOf,
          trace,
        );
      case QuestionIntent.time:
        return _pick(q, affirmed, (f) => f.time, refOf, trace);
      case QuestionIntent.manner:
        return _pick(q, affirmed, (f) => f.manner, refOf, trace);
      case QuestionIntent.agent:
        final stated = affirmed
            .where((f) => !f.unresolvedSubject && f.subjectText != null)
            .toList();
        if (stated.isEmpty) {
          final pronoun = affirmed.any((f) => f.unresolvedSubject);
          return unknown(
            note: pronoun ? 'unresolved reference' : 'agent not stated',
            evidence: affirmed,
            offer: !pronoun,
          );
        }
        return _agents(q, stated, refOf, trace);
      case QuestionIntent.object:
        final withObject = affirmed.where((f) => f.objectText != null).toList();
        if (withObject.isEmpty) return unknown(offer: true);
        final distinct = <String>[];
        for (final f in withObject) {
          if (!distinct.contains(f.objectText)) distinct.add(f.objectText!);
        }
        return Answer(
          question: q,
          status: EvidenceStatus.stated,
          answer: distinct.first,
          answers: distinct,
          evidence: _refs(withObject, refOf),
          attribution: _attribution(withObject),
          trace: trace,
        );
      default:
        return unknown();
    }
  }

  // ---- helpers ---------------------------------------------------------------------

  bool _participates(StoryQuestion q, Fact f) {
    // Every entity in the question must be part of the fact. For "who" the subject is
    // the answer, so it is not asked for.
    for (final e in q.entities) {
      if (!f.involves(e)) return false;
    }
    return true;
  }

  List<EvidenceRef> _refs(List<Fact> facts, EvidenceRef Function(Fact) refOf) {
    final seen = <String>{};
    return [
      for (final f in facts)
        if (seen.add('${f.sourceId}:${f.sentenceStart}')) refOf(f),
    ];
  }

  Attribution? _attribution(List<Fact> facts) {
    final a = facts.map((f) => f.attribution).toSet();
    return a.length == 1 ? a.first : null;
  }

  Answer _stated(
    StoryQuestion q,
    String text,
    List<Fact> facts,
    EvidenceRef Function(Fact) refOf,
    List<String> trace,
  ) => Answer(
    question: q,
    status: EvidenceStatus.stated,
    answer: text,
    evidence: _refs(facts, refOf),
    attribution: _attribution(facts),
    trace: trace,
  );

  /// "Who did it?" Several people in one sentence ("Edda and Iven carried it") are
  /// one answer naming all of them. Different passages naming different people clash.
  Answer _agents(
    StoryQuestion q,
    List<Fact> facts,
    EvidenceRef Function(Fact) refOf,
    List<String> trace,
  ) {
    final bySentence = <String, List<Fact>>{};
    for (final f in facts) {
      bySentence
          .putIfAbsent('${f.sourceId}:${f.sentenceStart}', () => [])
          .add(f);
    }
    String joined(List<Fact> fs) {
      final names = <String>[];
      for (final f in fs) {
        if (!names.contains(f.subjectText)) names.add(f.subjectText!);
      }
      return names.length <= 2
          ? names.join(' and ')
          : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    }

    final answers = <String>[];
    final seen = <String>{};
    for (final g in bySentence.values) {
      final ids = {
        for (final f in g) (f.subject ?? f.subjectText!).toLowerCase(),
      }.toList()..sort();
      if (seen.add(ids.join('+'))) answers.add(joined(g));
    }
    if (answers.length > 1) {
      trace.add('${answers.length} different answers');
      return Answer(
        question: q,
        status: EvidenceStatus.conflict,
        answers: answers,
        evidence: _refs(facts, refOf),
        trace: trace,
      );
    }
    return _stated(q, answers.first, facts, refOf, trace);
  }

  /// One slot's value from several facts: the same value is one answer, different
  /// values are a conflict.
  Answer _pick(
    StoryQuestion q,
    List<Fact> facts,
    String? Function(Fact) slot,
    EvidenceRef Function(Fact) refOf,
    List<String> trace, {
    String? Function(Fact)? byEntity,
  }) {
    final withSlot = facts.where((f) => slot(f) != null).toList();
    if (withSlot.isEmpty) {
      trace.add('facts found but none states it');
      return Answer(
        question: q,
        status: EvidenceStatus.unknown,
        evidence: _refs(facts, refOf),
        offerProposal: true,
        trace: trace,
      );
    }
    final key = byEntity ?? slot;
    final keys = <String>{};
    final values = <String>[];
    for (final f in withSlot) {
      if (keys.add((key(f) ?? slot(f))!.toLowerCase())) values.add(slot(f)!);
    }
    if (values.length > 1) {
      trace.add('${values.length} different answers');
      return Answer(
        question: q,
        status: EvidenceStatus.conflict,
        answers: values,
        evidence: _refs(withSlot, refOf),
        trace: trace,
      );
    }
    return _stated(q, values.first, withSlot, refOf, trace);
  }

  /// "What colour is the key?" Looks at every colour (or material) said of the thing.
  Answer _attribute(
    StoryQuestion q,
    List<Fact> facts,
    EvidenceRef Function(Fact) refOf,
    List<String> trace,
  ) {
    final kind = q.attributeKind == 'material'
        ? {...StoryLexicon.materials, ...StoryLexicon.metals}
        : StoryLexicon.colours;
    final subject = q.entities.first;
    final about = [
      for (final f in facts)
        if (sameEntity(f.subject, subject) &&
            f.relation == 'be' &&
            f.attribute != null &&
            kind.contains(f.attribute) &&
            f.polarity == 'affirmed' &&
            f.modality == 'certain')
          f,
    ];
    trace.add('${about.length} attribute fact(s) for $subject');
    if (about.isEmpty) {
      return Answer(
        question: q,
        status: EvidenceStatus.unknown,
        offerProposal: true,
        trace: trace,
      );
    }
    final narrator = about.where((f) => f.attribution == null).toList();
    final pool = narrator.isNotEmpty ? narrator : about;
    return _pick(q, pool, (f) => f.attribute, refOf, trace);
  }

  /// "Where is the key?" The key's position is whatever the latest event about it set.
  Answer _whereIs(
    StoryQuestion q,
    List<Fact> facts,
    EvidenceRef Function(Fact) refOf,
    List<String> trace,
  ) {
    final thing = q.entities.first;
    final events = <(Fact, _Move)>[];
    for (final f in facts) {
      if (f.polarity != 'affirmed' || f.modality != 'certain') continue;
      final move = _moveOf(f, thing);
      if (move != null) events.add((f, move));
    }
    trace.add('${events.length} event(s) about $thing');
    if (events.isEmpty) {
      return Answer(
        question: q,
        status: EvidenceStatus.unknown,
        offerProposal: true,
        trace: trace,
      );
    }
    // Narrator's own statements first; attributed ones only if there are no others.
    final narrator = events.where((e) => e.$1.attribution == null).toList();
    final pool = narrator.isNotEmpty ? narrator : events;
    pool.sort((a, b) => a.$1.order.compareTo(b.$1.order));
    final last = pool.last;
    if (last.$2.kind == _MoveKind.removed) {
      final earlier = pool
          .where(
            (e) =>
                e.$2.kind == _MoveKind.placed || e.$2.kind == _MoveKind.stated,
          )
          .toList();
      trace.add('the latest event moved it away');
      return Answer(
        question: q,
        status: EvidenceStatus.unknown,
        note: 'later moved',
        evidence: _refs([
          if (earlier.isNotEmpty) earlier.last.$1,
          last.$1,
        ], refOf),
        trace: trace,
      );
    }
    // Stative statements that disagree are a conflict; events that change place are not.
    final statedPlaces = pool
        .where((e) => e.$2.kind == _MoveKind.stated)
        .toList();
    final latestKind = last.$2.kind;
    if (latestKind == _MoveKind.stated) {
      final distinct = <String>{};
      final values = <String>[];
      for (final e in statedPlaces) {
        if (distinct.add(e.$2.placeKey)) values.add(e.$2.text);
      }
      if (values.length > 1) {
        return Answer(
          question: q,
          status: EvidenceStatus.conflict,
          answers: values,
          evidence: _refs([for (final e in statedPlaces) e.$1], refOf),
          trace: trace,
        );
      }
    }
    return Answer(
      question: q,
      status: latestKind == _MoveKind.stated
          ? EvidenceStatus.stated
          : EvidenceStatus.derived,
      answer: last.$2.text,
      evidence: _refs([last.$1], refOf),
      attribution: last.$1.attribution,
      trace: trace,
    );
  }

  _Move? _moveOf(Fact f, String thing) {
    // The thing is where it is said to be.
    if (sameEntity(f.subject, thing) &&
        _stative.contains(f.relation) &&
        f.location != null) {
      return _Move(
        _MoveKind.stated,
        f.location!.text,
        f.location!.entityId ?? f.location!.text,
      );
    }
    if (sameEntity(f.object, thing)) {
      final r = f.relation;
      if (_lex
              .synonyms(r)
              .intersection(StoryLexicon.placementVerbs)
              .isNotEmpty &&
          f.location != null) {
        return _Move(
          _MoveKind.placed,
          f.location!.text,
          f.location!.entityId ?? f.location!.text,
        );
      }
      if (f.destination != null) {
        return _Move(
          _MoveKind.placed,
          f.destination!.text,
          f.destination!.entityId ?? f.destination!.text,
        );
      }
      if (_lex
          .synonyms(r)
          .intersection(StoryLexicon.movementVerbs)
          .isNotEmpty) {
        return const _Move(_MoveKind.removed, '', '');
      }
    }
    return null;
  }
}

enum _MoveKind { stated, placed, removed }

class _Move {
  const _Move(this.kind, this.text, this.placeKey);
  final _MoveKind kind;
  final String text;
  final String placeKey;
}
