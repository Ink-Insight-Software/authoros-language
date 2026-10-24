// Evaluates the story-grounding pipeline on a corpus split.
//
//   dart run tool/story_eval.dart dev                 # development set, with details
//   dart run tool/story_eval.dart heldout --report out.json
//
// Reports, separately: tagging (POS, open-class lemma), fact extraction (exact fact
// match against the gold facts), question parsing (intent, relation, entities), and
// answers twice: from the gold parse of the question ("oracle") and from the parser
// ("end to end"). Every miss is listed so errors can be reviewed, not just counted.
import 'dart:convert';
import 'dart:io';

import 'package:authoros_language/src/story/story.dart';

const _openClass = {'NOUN', 'PROPN', 'VERB', 'ADJ', 'ADV'};

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

String norm(String? s) => (s ?? '').trim().toLowerCase();

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: story_eval.dart dev|heldout [--report file] [--quiet]',
    );
    exit(64);
  }
  final split = args.first;
  final quiet = args.contains('--quiet');
  final reportAt = args.contains('--report')
      ? args[args.indexOf('--report') + 1]
      : null;
  final file = File('corpus/story_v1/$split.jsonl');
  final records = [
    for (final l in file.readAsLinesSync())
      jsonDecode(l) as Map<String, dynamic>,
  ];

  final pos = Counter(), lemma = Counter();
  final posErrors = <String>[];
  final factHit = Counter(); // gold facts found
  var factsGold = 0, factsOut = 0, factsMatched = 0;
  final factMisses = <String>[];
  final parseIntent = Counter(),
      parseRelation = Counter(),
      parseEntities = Counter();
  final parseErrors = <String>[];
  final oracle = Counter(), endToEnd = Counter();
  final oracleStatus = Counter(), e2eStatus = Counter();
  final note = Counter(),
      offer = Counter(),
      attribution = Counter(),
      evidence = Counter();
  final byIntent = <String, Counter>{}, byStatus = <String, Counter>{};
  final qaErrors = <String>[];
  // Per-label tagging counts, evidence precision/recall, and the status confusion.
  final tp = <String, int>{}, fp = <String, int>{}, fn = <String, int>{};
  var evTp = 0, evPred = 0, evGold = 0;
  final confusion = <String, Map<String, int>>{};

  for (final r in records) {
    final registry = EntityRegistry([
      for (final e in r['project_entities'] as List)
        ProjectEntity.fromJson(e as Map<String, dynamic>),
    ]);
    final index = StoryIndex(registry);
    final sources = (r['sources'] as List).cast<Map<String, dynamic>>();
    final hasQuery = r['query'] != null;

    for (final s in sources) {
      final id = s['source_id'] as String;
      final text = s['text'] as String;
      final out = index.ingest(id, text);
      // Tagging, from the index's own extraction pass.
      final sentences = FactExtractor(
        registry: registry,
      ).extract(id, text).sentences;
      final got = [for (final x in sentences) ...x.tokens];
      final gold = (s['annotations']['tokens'] as List)
          .cast<Map<String, dynamic>>();
      if (got.length != gold.length) {
        posErrors.add(
          '$id: tokenisation differs (${got.length} vs ${gold.length})',
        );
      } else {
        for (var i = 0; i < got.length; i++) {
          final g = gold[i];
          final good = got[i].pos?.label == g['pos'];
          pos.add(good);
          final gl = g['pos'] as String, pl = got[i].pos?.label ?? '?';
          if (good) {
            tp[gl] = (tp[gl] ?? 0) + 1;
          } else {
            fn[gl] = (fn[gl] ?? 0) + 1;
            fp[pl] = (fp[pl] ?? 0) + 1;
          }
          if (!good) {
            posErrors.add(
              '$id "${got[i].text}": ${got[i].pos?.label} want ${g['pos']}',
            );
          }
          if (_openClass.contains(g['pos'])) {
            final lg = got[i].lemma == g['lemma'];
            lemma.add(lg);
            if (!lg) {
              posErrors.add(
                '$id "${got[i].text}": lemma ${got[i].lemma} want ${g['lemma']}',
              );
            }
          }
        }
      }
      // Fact extraction is scored only where the record is about questions.
      if (hasQuery) {
        final goldFacts = (s['annotations']['facts'] as List)
            .cast<Map<String, dynamic>>();
        final ours = [for (final f in out) f.toJson()];
        factsGold += goldFacts.length;
        factsOut += ours.length;
        final used = <int>{};
        for (final g in goldFacts) {
          var found = -1;
          for (var i = 0; i < ours.length; i++) {
            if (!used.contains(i) && _sameFact(g, ours[i])) {
              found = i;
              break;
            }
          }
          factHit.add(found >= 0);
          if (found >= 0) {
            used.add(found);
            factsMatched++;
          } else {
            factMisses.add(
              '$id missed ${_brief(g)}   got: ${ours.map(_brief).join(' | ')}',
            );
          }
        }
      }
    }
    if (!hasQuery) continue;

    final qd = r['query'] as Map<String, dynamic>;
    final exp = r['expected'] as Map<String, dynamic>;
    final parser = QuestionParser(index.extractor);
    final parsed = parser.parse(qd['text'] as String);
    parseIntent.add(parsed.intent.label == qd['intent']);
    parseRelation.add(parsed.relation == qd['relation']);
    final pe = {...parsed.entities},
        ge = {...(qd['entities'] as List).cast<String>()};
    parseEntities.add(pe.length == ge.length && pe.containsAll(ge));
    if (parsed.intent.label != qd['intent'] ||
        parsed.relation != qd['relation'] ||
        !(pe.length == ge.length && pe.containsAll(ge))) {
      parseErrors.add(
        '${r['record_id']} "${qd['text']}": ${parsed.intent.label}/${parsed.relation}/$pe want ${qd['intent']}/${qd['relation']}/$ge',
      );
    }

    final goldQ = StoryQuestion(
      text: qd['text'] as String,
      intent: QuestionIntent.parse(qd['intent'] as String),
      entities: (qd['entities'] as List).cast<String>(),
      relation: qd['relation'] as String?,
      attributeKind: norm(qd['text'] as String).contains('material')
          ? 'material'
          : 'colour',
    );
    for (final (label, ans, c, cs) in [
      ('oracle', index.answer(goldQ), oracle, oracleStatus),
      ('end-to-end', index.answer(parsed), endToEnd, e2eStatus),
    ]) {
      final status = exp['status'] as String;
      final conflict = status == 'CONFLICT';
      final wantAnswers = {
        for (final a in ((exp['answers'] ?? const []) as List))
          norm(a as String),
      };
      final answerOk = conflict
          ? ({for (final a in ans.answers) norm(a)}.length ==
                    wantAnswers.length &&
                {for (final a in ans.answers) norm(a)}.containsAll(wantAnswers))
          : norm(ans.answer) == norm(exp['answer'] as String?);
      final statusOk = ans.status.label == status;
      final wantEv = {...(exp['evidence_ids'] as List).cast<String>()};
      final evOk =
          ans.evidenceSourceIds.length == wantEv.length &&
          ans.evidenceSourceIds.containsAll(wantEv);
      final good = statusOk && answerOk && evOk;
      c.add(good);
      cs.add(statusOk);
      if (label == 'end-to-end') {
        byIntent.putIfAbsent(qd['intent'] as String, Counter.new).add(good);
        byStatus.putIfAbsent(status, Counter.new).add(good);
        evidence.add(evOk);
        evTp += ans.evidenceSourceIds.where(wantEv.contains).length;
        evPred += ans.evidenceSourceIds.length;
        evGold += wantEv.length;
        final row = confusion.putIfAbsent(status, () => {});
        row[ans.status.label] = (row[ans.status.label] ?? 0) + 1;
        if (exp['note'] != null) note.add(ans.note == exp['note']);
        offer.add(ans.offerProposal == (exp['offer_proposal'] == true));
        final wantAttr = exp['attribution'] as Map<String, dynamic>?;
        attribution.add(
          wantAttr == null
              ? ans.attribution == null
              : ans.attribution?.speaker == wantAttr['speaker'] &&
                    ans.attribution?.kind == wantAttr['kind'],
        );
      }
      if (!good) {
        qaErrors.add(
          '[$label] ${r['record_id']} "${qd['text']}"  got ${ans.status.label} '
          '"${ans.answer ?? ans.answers}" ev=${ans.evidenceSourceIds} note=${ans.note}  '
          'want $status "${exp['answer'] ?? exp['answers']}" ev=$wantEv note=${exp['note']}',
        );
      }
    }
  }

  final p = factsOut == 0 ? 0.0 : factsMatched / factsOut;
  final rc = factsGold == 0 ? 0.0 : factsMatched / factsGold;
  final f1 = p + rc == 0 ? 0.0 : 2 * p * rc / (p + rc);
  String f(double x) => (100 * x).toStringAsFixed(1);

  final b = StringBuffer()
    ..writeln('Story grounding evaluation: $split (${records.length} records)')
    ..writeln('')
    ..writeln('Tagging            POS $pos   open-class lemma $lemma')
    ..writeln(
      'Fact extraction    precision ${f(p)}%  recall ${f(rc)}%  F1 ${f(f1)}%   ($factsMatched matched, $factsGold gold, $factsOut produced)',
    )
    ..writeln(
      'Question parsing   intent $parseIntent   relation $parseRelation   entities $parseEntities',
    )
    ..writeln(
      'Answers (oracle query)      correct $oracle   status only $oracleStatus',
    )
    ..writeln(
      'Answers (end to end)        correct $endToEnd   status only $e2eStatus',
    )
    ..writeln(
      '  evidence ids $evidence   note $note   offer-proposal flag $offer   attribution $attribution',
    )
    ..writeln(
      '  by intent: ${byIntent.entries.map((e) => '${e.key} ${e.value}').join(', ')}',
    )
    ..writeln(
      '  by status: ${byStatus.entries.map((e) => '${e.key} ${e.value}').join(', ')}',
    )
    ..writeln(
      '  evidence precision ${evPred == 0 ? 'n/a' : f(evTp / evPred)}%  recall ${evGold == 0 ? 'n/a' : f(evTp / evGold)}%',
    )
    ..writeln(
      '  status confusion (gold -> predicted): ${confusion.entries.map((e) => '${e.key}: ${e.value}').join('; ')}',
    )
    ..writeln('  per-label POS (precision / recall / F1, support):');
  for (final label in ({...tp.keys, ...fn.keys}.toList()..sort())) {
    final t = tp[label] ?? 0,
        pp = t + (fp[label] ?? 0),
        gg = t + (fn[label] ?? 0);
    final pr = pp == 0 ? 0.0 : t / pp, re = gg == 0 ? 0.0 : t / gg;
    final f1l = pr + re == 0 ? 0.0 : 2 * pr * re / (pr + re);
    b.writeln(
      '    ${label.padRight(6)} ${f(pr)} / ${f(re)} / ${f(f1l)}   n=$gg',
    );
  }
  print(b);
  if (!quiet) {
    for (final (title, list) in [
      ('Tagging errors', posErrors),
      ('Fact extraction misses', factMisses),
      ('Question parsing errors', parseErrors),
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
        'tagging': {
          'pos': pos.toJson(),
          'open_class_lemma': lemma.toJson(),
          'per_label': {
            for (final label in {...tp.keys, ...fn.keys})
              label: {
                'tp': tp[label] ?? 0,
                'fp': fp[label] ?? 0,
                'fn': fn[label] ?? 0,
              },
          },
        },
        'evidence': {
          'true_positive': evTp,
          'predicted': evPred,
          'gold': evGold,
        },
        'status_confusion': confusion,
        'fact_extraction': {
          'precision': p,
          'recall': rc,
          'f1': f1,
          'matched': factsMatched,
          'gold': factsGold,
          'produced': factsOut,
        },
        'question_parsing': {
          'intent': parseIntent.toJson(),
          'relation': parseRelation.toJson(),
          'entities': parseEntities.toJson(),
        },
        'answers_oracle': {
          'correct': oracle.toJson(),
          'status': oracleStatus.toJson(),
        },
        'answers_end_to_end': {
          'correct': endToEnd.toJson(),
          'status': e2eStatus.toJson(),
          'evidence': evidence.toJson(),
          'note': note.toJson(),
          'offer_proposal': offer.toJson(),
          'attribution': attribution.toJson(),
          'by_intent': {
            for (final e in byIntent.entries) e.key: e.value.toJson(),
          },
          'by_status': {
            for (final e in byStatus.entries) e.key: e.value.toJson(),
          },
        },
        'errors': {
          'tagging': posErrors,
          'fact_extraction': factMisses,
          'question_parsing': parseErrors,
          'answers': qaErrors,
        },
      }),
    );
  }
}

const _slots = [
  'subject',
  'relation',
  'object',
  'location',
  'destination',
  'origin',
  'recipient',
  'time',
  'manner',
  'attribute',
  'polarity',
  'modality',
];

bool _sameFact(Map<String, dynamic> gold, Map<String, dynamic> ours) {
  for (final k in _slots) {
    final g = gold[k], o = ours[k];
    if (g is String && o is String
        ? g.toLowerCase() != o.toLowerCase()
        : g != o) {
      return false;
    }
  }
  final ga = gold['attribution'] as Map<String, dynamic>?;
  final oa = ours['attribution'] as Map<String, dynamic>?;
  if ((ga == null) != (oa == null)) return false;
  if (ga != null &&
      (ga['speaker'] != oa!['speaker'] || ga['kind'] != oa['kind'])) {
    return false;
  }
  return true;
}

String _brief(Map<String, dynamic> f) {
  final parts = <String>[];
  for (final k in _slots) {
    final v = f[k];
    if (v == null ||
        (k == 'polarity' && v == 'affirmed') ||
        (k == 'modality' && v == 'certain')) {
      continue;
    }
    parts.add('$k=$v');
  }
  final a = f['attribution'];
  if (a != null) parts.add('attr=$a');
  return '{${parts.join(' ')}}';
}
