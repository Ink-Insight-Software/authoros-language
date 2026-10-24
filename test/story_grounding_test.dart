import 'dart:convert';
import 'dart:io';

import 'package:authoros_language/authoros_language.dart';
import 'package:test/test.dart';

EntityRegistry _registry() => EntityRegistry(const [
  ProjectEntity(
    id: 'char_mara',
    type: EntityType.character,
    names: ['Mara'],
    pronouns: 'she',
  ),
  ProjectEntity(
    id: 'char_iven',
    type: EntityType.character,
    names: ['Iven'],
    pronouns: 'he',
  ),
  ProjectEntity(
    id: 'char_edda',
    type: EntityType.character,
    names: ['Edda'],
    pronouns: 'she',
  ),
]);

StoryIndex _story(List<String> passages) {
  final index = StoryIndex(_registry());
  for (var i = 0; i < passages.length; i++) {
    index.ingest('s${i + 1}', passages[i]);
  }
  return index;
}

void main() {
  group('tokenizer', () {
    const tokenizer = StoryTokenizer();

    test('offsets always point at the token in the original text', () {
      const text = 'Mr. Hale didn\'t see "Mara\'s" key... Then he left!';
      for (final s in tokenizer.tokenize(text)) {
        for (final t in s.tokens) {
          expect(text.substring(t.start, t.end), t.text);
        }
      }
    });

    test('does not split a sentence at an abbreviation', () {
      expect(
        tokenizer.tokenize('Mr. Hale left. He did not return.'),
        hasLength(2),
      );
    });

    test('splits contractions the Universal Dependencies way', () {
      final tokens = tokenizer.tokenize("She didn't know.").single.tokens;
      expect(tokens.map((t) => t.text), ['She', 'did', "n't", 'know', '.']);
    });

    test('a closing quote stays with its sentence', () {
      final s = tokenizer.tokenize('Iven said, “Mara hid the key.” Mara left.');
      expect(s, hasLength(2));
      expect(s.first.text.endsWith('”'), isTrue);
    });
  });

  group('the development corpus', () {
    final records = [
      for (final l in File('corpus/story_v1/dev.jsonl').readAsLinesSync())
        jsonDecode(l) as Map<String, dynamic>,
    ];

    test('every question is answered as the corpus says', () {
      final wrong = <String>[];
      for (final r in records.where((r) => r['query'] != null)) {
        final registry = EntityRegistry([
          for (final e in r['project_entities'] as List)
            ProjectEntity.fromJson(e as Map<String, dynamic>),
        ]);
        final index = StoryIndex(registry);
        for (final s in r['sources'] as List) {
          index.ingest(s['source_id'] as String, s['text'] as String);
        }
        final a = index.ask((r['query'] as Map)['text'] as String);
        final want = r['expected'] as Map<String, dynamic>;
        final ok =
            a.status.label == want['status'] &&
            a.evidenceSourceIds.containsAll(
              (want['evidence_ids'] as List).cast<String>(),
            ) &&
            a.evidenceSourceIds.length ==
                (want['evidence_ids'] as List).length &&
            (want['status'] == 'CONFLICT'
                ? a.answers
                      .map((x) => x.toLowerCase())
                      .toSet()
                      .containsAll(
                        (want['answers'] as List).map(
                          (x) => (x as String).toLowerCase(),
                        ),
                      )
                : (a.answer ?? '').toLowerCase() ==
                      ((want['answer'] as String?) ?? '').toLowerCase());
        if (!ok) wrong.add(r['record_id'] as String);
      }
      expect(wrong, isEmpty);
    });
  });

  group('answers and their status', () {
    test('stated, with the exact sentence as evidence', () {
      final index = _story([
        'Mara quietly hid the silver key beneath the chapel floor before dawn.',
      ]);
      final a = index.ask('Where did Mara hide the key?');
      expect(a.status, EvidenceStatus.stated);
      expect(a.answer, 'beneath the chapel floor');
      final ref = a.evidence.single;
      expect(
        index.source(ref.sourceId)!.text.substring(ref.start, ref.end),
        ref.quote,
      );
      expect(ref.quote, startsWith('Mara quietly hid'));
    });

    test('derived: where it ended up is worked out, and says so', () {
      final index = _story(['Iven placed the lantern on the table.']);
      expect(
        index.ask('Where did Iven put the lantern?').status,
        EvidenceStatus.stated,
      );
      final where = index.ask('Where is the lantern?');
      expect(where.status, EvidenceStatus.derived);
      expect(where.answer, 'on the table');
    });

    test(
      'a later action that moves it makes the place unknown, not a guess',
      () {
        final index = _story([
          'Mara hid the key beneath the chapel floor.',
          'Iven took the key from the chapel.',
        ]);
        final a = index.ask('Where is the key?');
        expect(a.status, EvidenceStatus.unknown);
        expect(a.note, 'later moved');
        expect(a.evidenceSourceIds, {'s1', 's2'});
      },
    );

    test('unknown when the story is silent, and an offer is allowed', () {
      final a = _story([
        'Iven walked to the market.',
      ]).ask('Where is the sword?');
      expect(a.status, EvidenceStatus.unknown);
      expect(a.offerProposal, isTrue);
      expect(a.evidence, isEmpty);
    });

    test('conflict names both answers and both sources', () {
      final a = _story([
        'The key was black.',
        'Mara slid the silver key into her pocket.',
      ]).ask('What colour is the key?');
      expect(a.status, EvidenceStatus.conflict);
      expect(a.answers.toSet(), {'black', 'silver'});
      expect(a.evidenceSourceIds, {'s1', 's2'});
    });

    test(
      'negation answers a yes/no question and is never evidence for where',
      () {
        final index = _story(['Mara did not hide the key.']);
        expect(index.ask('Did Mara hide the key?').answer, 'No');
        final where = index.ask('Where did Mara hide the key?');
        expect(where.status, EvidenceStatus.unknown);
        expect(where.evidence, isEmpty);
      },
    );

    test('a possibility is reported as a possibility', () {
      final a = _story([
        'Mara might hide the key.',
      ]).ask('Did Mara hide the key?');
      expect(a.status, EvidenceStatus.unknown);
      expect(a.note, 'possibility only');
      expect(a.evidenceSourceIds, {'s1'});
    });

    test('"could not" is a negation, "might" is a possibility', () {
      expect(
        _story([
          'Mara could not find the map.',
        ]).ask('Did Mara find the map?').answer,
        'No',
      );
      expect(
        _story([
          'Mara might not find the map.',
        ]).ask('Did Mara find the map?').note,
        'possibility only',
      );
    });

    test('reported speech keeps who said it', () {
      final a = _story([
        'Mara told Iven that she hid the key.',
      ]).ask('Did Mara hide the key?');
      expect(a.answer, 'Yes');
      expect(a.attribution!.speaker, 'char_mara');
      expect(a.attribution!.kind, 'reported');
    });

    test('a belief is labelled a belief', () {
      final a = _story([
        'Iven believed that the key was under the pier.',
      ]).ask('Where is the key?');
      expect(a.answer, 'under the pier');
      expect(a.attribution!.kind, 'belief');
    });

    test('the narrator outranks what a character claimed', () {
      final a = _story([
        'Iven believed that the key was under the pier.',
        'The key was in the barn.',
      ]).ask('Where is the key?');
      expect(a.answer, 'in the barn');
      expect(a.attribution, isNull);
    });
  });

  group('pronouns', () {
    test(
      'a pronoun with one candidate resolves, and the answer is the name',
      () {
        final a = _story([
          'Mara found a silver key in the courtyard.',
          'She hid it beneath the chapel floor.',
        ]).ask('Who hid the key?');
        expect(a.answer, 'Mara');
        expect(a.evidenceSourceIds, {'s2'});
      },
    );

    test('a pronoun with two candidates is not guessed', () {
      final a = _story([
        'Edda and Mara argued by the gate.',
        'She took the map.',
      ]).ask('Who took the map?');
      expect(a.status, EvidenceStatus.unknown);
      expect(a.note, 'ambiguous pronoun');
    });
  });

  group('coordination and phrasing', () {
    test('two people in one sentence are one answer naming both', () {
      final a = _story([
        'Edda and Iven carried the chest into the cellar.',
      ]).ask('Who carried the chest?');
      expect(a.status, EvidenceStatus.stated);
      expect(a.answer, 'Edda and Iven');
    });

    test('two objects are both found', () {
      final a = _story([
        'Iven took the key and the map.',
      ]).ask('What did Iven take?');
      expect(a.answers, ['the key', 'the map']);
    });

    test('a verb in the question finds its synonym in the story', () {
      expect(
        _story([
          'Iven grabbed the lamp from the shelf.',
        ]).ask('What did Iven take?').answer,
        'the lamp',
      );
      expect(
        _story(['Mara hid the key.']).ask('Who concealed the key?').answer,
        'Mara',
      );
    });

    test('a place after a motion verb is where she went', () {
      final a = _story(['Mara entered the hall.']).ask('Where did Mara enter?');
      expect(a.answer, 'the hall');
    });

    test(
      'a question the pipeline does not understand is UNKNOWN, not a guess',
      () {
        final a = _story(['Mara hid the key.']).ask('How many keys are there?');
        expect(a.status, EvidenceStatus.unknown);
        expect(a.note, 'question not understood');
      },
    );

    test('a question in the manuscript yields no fact', () {
      expect(_story(['Where did Mara hide the key?']).facts, isEmpty);
    });
  });

  group('the index', () {
    test('replacing a passage rebuilds in order', () {
      final index = _story(['Mara hid the key beneath the chapel floor.']);
      index.replace('s1', 'Mara hid the key behind the clock.');
      expect(
        index.ask('Where did Mara hide the key?').answer,
        'behind the clock',
      );
    });

    test('removing a passage removes what it said', () {
      final index = _story(['Mara hid the key beneath the chapel floor.']);
      index.remove('s1');
      expect(
        index.ask('Where did Mara hide the key?').status,
        EvidenceStatus.unknown,
      );
    });

    test('ingesting the same source twice is refused', () {
      final index = _story(['Mara hid the key.']);
      expect(() => index.ingest('s1', 'Iven left.'), throwsArgumentError);
    });

    test(
      'an unregistered name is recorded so the author can be offered it',
      () {
        final index = StoryIndex(_registry())
          ..ingest('s1', 'Tilda hid the key.');
        expect(index.extractor.unregisteredNames, contains('Tilda'));
      },
    );
  });

  group('proposal mode', () {
    StoryIndex silent() => _story([
      'Mara hid the key beneath the chapel floor.',
      'Iven walked to the market.',
    ]);

    test('proposals are PROPOSED, grounded, and never reach the index', () {
      final index = silent();
      final before = index.facts.length;
      final unknown = index.ask('Where is the sword?');
      final proposals = const GroundedProposalGenerator().propose(
        unknown,
        index,
      );
      expect(proposals, isNotEmpty);
      for (final p in proposals) {
        expect(p.status, EvidenceStatus.proposed);
        expect(p.grounding, isNotEmpty);
      }
      final ledger = ProposalLedger()..offer(proposals, index);
      expect(index.facts.length, before);
      expect(index.ask('Where is the sword?').status, EvidenceStatus.unknown);
      expect(ledger.open, isNotEmpty);
    });

    test('nothing is offered when the story is not simply silent', () {
      final index = _story([
        'Mara hid the key beneath the chapel floor.',
        'Iven took the key from the chapel.',
      ]);
      final a = index.ask('Where is the key?');
      expect(const GroundedProposalGenerator().propose(a, index), isEmpty);
    });

    test(
      'the guard refuses a proposal that cites nothing or cites text that is not there',
      () {
        final index = silent();
        const bare = Proposal(
          id: 'x',
          text: 'Maybe.',
          question: 'q',
          grounding: [],
          rationale: '',
        );
        expect(const ProposalGuard().check(bare, index), isNotNull);
        const forged = Proposal(
          id: 'y',
          text: 'Maybe.',
          question: 'q',
          grounding: [
            EvidenceRef(sourceId: 's1', start: 0, end: 4, quote: 'Nope'),
          ],
          rationale: '',
        );
        expect(const ProposalGuard().check(forged, index), isNotNull);
        expect(ProposalLedger().offer([bare, forged], index), isEmpty);
      },
    );

    test(
      'approval is the only way out, returns the grounding, and cannot repeat',
      () {
        final index = silent();
        final unknown = index.ask('Where is the sword?');
        final ledger = ProposalLedger();
        final shown = ledger.offer(
          const GroundedProposalGenerator().propose(unknown, index),
          index,
        );
        final approved = ledger.approve(shown.first.id);
        expect(approved, isNotNull);
        expect(approved!.grounding, isNotEmpty);
        expect(ledger.approve(shown.first.id), isNull);
      },
    );

    test('a rejected proposal is not offered again', () {
      final index = silent();
      final unknown = index.ask('Where is the sword?');
      final ledger = ProposalLedger();
      final first = ledger.offer(
        const GroundedProposalGenerator().propose(unknown, index),
        index,
      );
      ledger.reject(first.first.id);
      final again = ledger.offer(
        const GroundedProposalGenerator().propose(unknown, index),
        index,
      );
      expect(again.map((p) => p.id), isNot(contains(first.first.id)));
    });
  });
}
