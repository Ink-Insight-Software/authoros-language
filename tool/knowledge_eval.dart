// Evaluates Character Knowledge Continuity on a corpus split.
//
//   dart run tool/knowledge_eval.dart dev
//   dart run tool/knowledge_eval.dart heldout --report out.json
//
// Reports, separately: knowledge-event extraction (against the gold events), answers to
// knowledge questions twice (from the gold-structured query, and from the question
// text), and the knowledge-leak review items. Every miss is listed.
import 'dart:convert';
import 'dart:io';

import 'package:authoros_language/src/story/story.dart';

class Counter {
  int ok = 0, total = 0;
  void add(bool good) {
    total++;
    if (good) ok++;
  }

  String get pct =>
      total == 0 ? 'n/a' : '${(100 * ok / total).toStringAsFixed(1)}%';
  @override
  String toString() => '$ok/$total ($pct)';
  Map<String, dynamic> toJson() => {'correct': ok, 'total': total};
}

Proposition propOf(Map<String, dynamic> p) => Proposition(
  relation: p['relation'] as String,
  subject: p['subject'] as String?,
  object: p['object'] as String?,
  location: p['location'] as String?,
  attribute: p['attribute'] as String?,
);

String evKey(
  String character,
  Proposition p,
  String state,
  String? route,
  String source,
) =>
    '$character|${p.relation}|${p.subject}|${p.object}|${p.isState ? p.location : ''}|$state|$route|$source';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: knowledge_eval.dart dev|heldout [--report file] [--quiet]',
    );
    exit(64);
  }
  final split = args.first;
  final quiet = args.contains('--quiet');
  final reportAt = args.contains('--report')
      ? args[args.indexOf('--report') + 1]
      : null;
  final records = [
    for (final l in File('corpus/knowledge_v1/$split.jsonl').readAsLinesSync())
      jsonDecode(l) as Map<String, dynamic>,
  ];

  var evTp = 0, evPred = 0, evGold = 0;
  final evMisses = <String>[];
  final oracle = Counter(), endToEnd = Counter();
  final canon = Counter(), note = Counter();
  final byKind = <String, Counter>{};
  final byState = <String, Counter>{};
  final leakCounter = Counter();
  final qaErrors = <String>[];
  final confusion = <String, Map<String, int>>{};

  for (final r in records) {
    final registry = EntityRegistry([
      for (final e in r['project_entities'] as List)
        ProjectEntity.fromJson(e as Map<String, dynamic>),
    ]);
    final timeline = StoryTimeline([
      for (final t in r['timeline'] as List)
        TimelineEntry(t['id'] as String, t['label'] as String),
    ]);
    final index = StoryIndex(registry, timeline: timeline);
    for (final s in r['sources'] as List) {
      index.ingest(
        s['source_id'] as String,
        s['text'] as String,
        storyTimeId: s['story_time_id'] as String,
      );
    }
    for (final a in r['author_records'] as List) {
      index.addAuthorKnowledge(
        AuthorKnowledgeRecord(
          recordId: a['record_id'] as String,
          characterId: a['character_id'] as String,
          storyTimeId: a['story_time_id'] as String,
          state: KnowledgeState.parse(a['knowledge_state'] as String)!,
          text: a['text'] as String,
          note: a['note'] as String?,
        ),
      );
    }

    // ---- event extraction ----
    final gold = (r['gold_events'] as List).cast<Map<String, dynamic>>();
    if (gold.isNotEmpty) {
      final want = {
        for (final g in gold)
          evKey(
            g['character_id'] as String,
            propOf(g['proposition'] as Map<String, dynamic>),
            g['knowledge_state'] as String,
            g['acquisition_route'] as String?,
            g['source_id'] as String,
          ),
      };
      final got = {
        for (final e in index.knowledge.events)
          if (!e.possible && e.route != AcquisitionRoute.authorEntered)
            evKey(
              e.characterId,
              e.proposition,
              e.state.label,
              e.route?.label,
              e.sourceId,
            ): e,
      };
      evGold += want.length;
      evPred += got.length;
      evTp += want.where(got.containsKey).length;
      for (final w in want.where((w) => !got.containsKey(w))) {
        evMisses.add(
          '${r['record_id']} missed $w   produced: ${got.keys.join(' ; ')}',
        );
      }
      for (final x in got.keys.where((g) => !want.contains(g))) {
        evMisses.add('${r['record_id']} extra  $x');
      }
    }

    // ---- questions ----
    final q = r['query'] as Map<String, dynamic>;
    final exp = r['expected'] as Map<String, dynamic>;
    final kind = q['kind'] as String;
    if (kind == 'leak_check') {
      final got = {
        for (final l in index.knowledgeLeaks())
          '${l.characterId}|${l.action.sourceId}|${l.proposition.sourceId}',
      };
      final want = {
        for (final l in (exp['leaks'] as List))
          '${l['character_id']}|${l['action_source_id']}|${l['proposition_source_id']}',
      };
      final good = got.length == want.length && got.containsAll(want);
      leakCounter.add(good);
      byKind.putIfAbsent(kind, Counter.new).add(good);
      if (!good) qaErrors.add('${r['record_id']} leaks: got $got want $want');
      continue;
    }

    final goldProp = propOf(q['proposition'] as Map<String, dynamic>);
    final at = q['story_time_id'] as String?;
    final goldAnswer = switch (kind) {
      'knows' => index.knowledge.knowsAt(
        q['character_id'] as String,
        goldProp,
        at: at,
      ),
      'who_knows' => index.knowledge.whoKnows(goldProp, at: at),
      _ => index.knowledge.whenLearned(q['character_id'] as String, goldProp),
    };
    final textAnswer = index.askKnowledge(q['text'] as String);
    final wantEv = {...(exp['evidence_ids'] as List).cast<String>()};

    bool correct(KnowledgeAnswer a) {
      if (a.status.label != exp['status']) return false;
      final evOk =
          a.evidenceSourceIds.length == wantEv.length &&
          a.evidenceSourceIds.containsAll(wantEv);
      if (!evOk) return false;
      return switch (kind) {
        'knows' =>
          a.state?.label == exp['knowledge_state'] &&
              a.route?.label == exp['acquisition_route'],
        'who_knows' =>
          {...a.who}.length == (exp['who'] as List).length &&
              {...a.who}.containsAll((exp['who'] as List).cast<String>()),
        _ => a.storyTimeId == exp['story_time_id'],
      };
    }

    final okOracle = correct(goldAnswer), okText = correct(textAnswer);
    oracle.add(okOracle);
    endToEnd.add(okText);
    byKind.putIfAbsent(kind, Counter.new).add(okText);
    if (kind == 'knows') {
      byState.putIfAbsent('${exp['knowledge_state']}', Counter.new).add(okText);
      canon.add(textAnswer.matchesCanon == exp['matches_canon']);
      if (exp['note'] != null) note.add(textAnswer.note == exp['note']);
      final row = confusion.putIfAbsent('${exp['knowledge_state']}', () => {});
      row['${textAnswer.state?.label}'] =
          (row['${textAnswer.state?.label}'] ?? 0) + 1;
    }
    for (final (label, a, good) in [
      ('oracle', goldAnswer, okOracle),
      ('end-to-end', textAnswer, okText),
    ]) {
      if (!good) {
        qaErrors.add(
          '[$label] ${r['record_id']} "${q['text']}"  got ${a.status.label} state=${a.state?.label} route=${a.route?.label} '
          'who=${a.who} time=${a.storyTimeId} ev=${a.evidenceSourceIds} note=${a.note}   '
          'want ${exp['status']} state=${exp['knowledge_state']} route=${exp['acquisition_route']} '
          'who=${exp['who']} time=${exp['story_time_id']} ev=$wantEv',
        );
      }
    }
  }

  String f(double x) => (100 * x).toStringAsFixed(1);
  final p = evPred == 0 ? 0.0 : evTp / evPred,
      rc = evGold == 0 ? 0.0 : evTp / evGold;
  final f1 = p + rc == 0 ? 0.0 : 2 * p * rc / (p + rc);
  final b = StringBuffer()
    ..writeln(
      'Character knowledge evaluation: $split (${records.length} records)',
    )
    ..writeln('')
    ..writeln(
      'Event extraction   precision ${f(p)}%  recall ${f(rc)}%  F1 ${f(f1)}%   ($evTp matched, $evGold gold, $evPred produced)',
    )
    ..writeln('Answers (oracle query)   correct $oracle')
    ..writeln('Answers (end to end)     correct $endToEnd')
    ..writeln('  matches-canon flag $canon   note $note')
    ..writeln(
      '  by kind: ${byKind.entries.map((e) => '${e.key} ${e.value}').join(', ')}',
    )
    ..writeln(
      '  by knowledge state: ${byState.entries.map((e) => '${e.key} ${e.value}').join(', ')}',
    )
    ..writeln(
      '  state confusion (gold -> predicted): ${confusion.entries.map((e) => '${e.key}: ${e.value}').join('; ')}',
    )
    ..writeln(
      'Leak review items         exact set match per record $leakCounter',
    );
  print(b);
  if (!quiet) {
    for (final (title, list) in [
      ('Event extraction differences', evMisses),
      ('Answer errors', qaErrors),
    ]) {
      if (list.isEmpty) continue;
      print('$title (${list.length}):');
      for (final e in list) {
        print('  $e');
      }
      print('');
    }
  }
  if (reportAt != null) {
    File(reportAt).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'split': split,
        'records': records.length,
        'event_extraction': {
          'precision': p,
          'recall': rc,
          'f1': f1,
          'matched': evTp,
          'gold': evGold,
          'produced': evPred,
        },
        'answers_oracle': oracle.toJson(),
        'answers_end_to_end': endToEnd.toJson(),
        'matches_canon': canon.toJson(),
        'note': note.toJson(),
        'by_kind': {for (final e in byKind.entries) e.key: e.value.toJson()},
        'by_knowledge_state': {
          for (final e in byState.entries) e.key: e.value.toJson(),
        },
        'state_confusion': confusion,
        'leaks': leakCounter.toJson(),
        'errors': {'events': evMisses, 'answers': qaErrors},
      }),
    );
  }
}
