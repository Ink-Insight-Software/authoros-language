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

/// Passages as (story time, text), in story order; source ids are s1, s2, ...
StoryIndex _story(List<(String, String)> passages) {
  // The application supplies the whole timeline, so "by Chapter 3" exists even before any
  // passage is set in it.
  final index = StoryIndex(
    _registry(),
    timeline: StoryTimeline([
      for (var n = 1; n <= 5; n++) TimelineEntry('chapter_0$n', 'Chapter $n'),
    ]),
  );
  for (var i = 0; i < passages.length; i++) {
    index.ingest('s${i + 1}', passages[i].$2, storyTimeId: passages[i].$1);
  }
  return index;
}

void main() {
  group('how a character comes to know', () {
    test('told something the narrator confirms: knows, and says how', () {
      final a = _story([
        ('chapter_01', 'Mara hid the key beneath the chapel floor.'),
        ('chapter_02', 'Mara told Iven that she hid the key.'),
      ]).askKnowledge('Does Iven know Mara hid the key by Chapter 3?');
      expect(a.status, EvidenceStatus.stated);
      expect(a.state, KnowledgeState.knows);
      expect(a.route, AcquisitionRoute.told);
      expect(a.evidenceSourceIds, {'s2'});
      expect(a.matchesCanon, isTrue);
    });

    test(
      'told something the narrator does not confirm: believes, not knows',
      () {
        final a = _story([
          ('chapter_02', 'Mara told Iven that Edda stole the ledger.'),
        ]).askKnowledge('Does Iven know Edda stole the ledger?');
        expect(a.state, KnowledgeState.believes);
        expect(a.matchesCanon, isNull);
      },
    );

    test('a false belief stays a belief and says the story disagrees', () {
      final a = _story([
        ('chapter_01', 'The key was in the barn.'),
        ('chapter_02', 'Iven believed that the key was under the pier.'),
      ]).askKnowledge('Does Iven know the key was under the pier?');
      expect(a.state, KnowledgeState.believes);
      expect(a.matchesCanon, isFalse);
      expect(a.status, EvidenceStatus.stated);
    });

    test(
      'witnessing and noticing are WITNESSED, hearing is OVERHEARD, reading is READ',
      () {
        final index = _story([
          ('c1', 'Edda watched Mara hide the key.'),
          ('c2', 'Iven heard that Edda left the village.'),
          ('c3', 'Mara read that Iven left the village.'),
        ]);
        expect(
          index.askKnowledge('Does Edda know Mara hid the key?').route,
          AcquisitionRoute.witnessed,
        );
        expect(
          index.askKnowledge('Does Iven know Edda left the village?').route,
          AcquisitionRoute.overheard,
        );
        expect(
          index.askKnowledge('Does Mara know Iven left the village?').route,
          AcquisitionRoute.read,
        );
      },
    );

    test('a pronoun in "saw her hide it" is resolved', () {
      final a = _story([
        ('c1', 'Mara hid the key.'),
        ('c1', 'Iven saw her hide it.'),
      ]).askKnowledge('Does Iven know Mara hid the key?');
      expect(a.state, KnowledgeState.knows);
      expect(a.route, AcquisitionRoute.witnessed);
    });

    test(
      '"she" inside what was told is the teller when only the teller is named in that sentence',
      () {
        final a = _story([
          ('c1', 'Rowan watched Edda and Mara leave.'),
          ('c2', 'Mara told Iven that she hid the key.'),
        ]).askKnowledge('Does Iven know Mara hid the key?');
        expect(a.state, KnowledgeState.believes);
        expect(a.evidenceSourceIds, {'s2'});
      },
    );

    test(
      '"she" stays unresolved when two women are named in the same sentence',
      () {
        final index = _story([('c1', 'Mara told Edda that she hid the key.')]);
        expect(index.facts.single.subject, isNull);
        expect(index.facts.single.unresolvedSubject, isTrue);
      },
    );

    test('a negated or hedged telling records nothing at all', () {
      for (final text in [
        'Mara did not tell Iven that she hid the key.',
        'Mara might tell Iven that she hid the key.',
      ]) {
        final index = _story([('c1', text)]);
        expect(index.facts, isEmpty, reason: text);
        expect(
          index.askKnowledge('Does Iven know Mara hid the key?').note,
          'no recorded acquisition found',
        );
      }
    });

    test(
      '"did not know that" is stated unawareness; "might know" is only a possibility',
      () {
        final unaware = _story([
          ('c1', 'Mara hid the key.'),
          ('c2', 'Iven did not know that Mara hid the key.'),
        ]).askKnowledge('Does Iven know Mara hid the key?');
        expect(unaware.state, KnowledgeState.unawareInText);
        final hedged = _story([
          ('c1', 'Iven might know that Mara hid the key.'),
        ]).askKnowledge('Does Iven know Mara hid the key?');
        expect(hedged.status, EvidenceStatus.unknown);
        expect(hedged.note, 'possibility only');
      },
    );
  });

  group('no record is not ignorance', () {
    test(
      'with nothing on file the answer is UNKNOWN, never "does not know"',
      () {
        final a = _story([
          ('c1', 'Mara hid the key.'),
        ]).askKnowledge('Does Iven know Mara hid the key?');
        expect(a.status, EvidenceStatus.unknown);
        expect(a.state, isNull);
        expect(a.note, 'no recorded acquisition found');
      },
    );

    test(
      'learning it only later is reported as later, not as ignorance before',
      () {
        final a = _story([
          ('chapter_01', 'Mara hid the key.'),
          ('chapter_04', 'Iven saw Mara hide the key.'),
        ]).askKnowledge('Does Iven know Mara hid the key by Chapter 3?');
        expect(a.status, EvidenceStatus.unknown);
        expect(a.note, 'first recorded acquisition is later');
        expect(a.evidenceSourceIds, {'s2'});
      },
    );

    test(
      'two passages that disagree about awareness at one moment are a conflict',
      () {
        final a = _story([
          ('c1', 'Iven knew that Mara hid the key.'),
          ('c1', 'Iven did not know that Mara hid the key.'),
        ]).askKnowledge('Does Iven know Mara hid the key?');
        expect(a.status, EvidenceStatus.conflict);
        expect(a.evidenceSourceIds, {'s1', 's2'});
      },
    );
  });

  group('continuity anomalies and repeatability', () {
    test(
      'knowing and later recorded as unaware is a conflict, with both passages',
      () {
        final a = _story([
          ('chapter_01', 'Iven learned that Mara hid the key.'),
          ('chapter_03', 'Iven did not know that Mara hid the key.'),
        ]).askKnowledge('Does Iven know Mara hid the key by Chapter 3?');
        expect(a.status, EvidenceStatus.conflict);
        expect(a.note, 'recorded as knowing earlier');
        expect(a.evidenceSourceIds, {'s1', 's2'});
      },
    );

    test('the same inputs always give the same events and answers', () {
      String run() {
        final index = _story([
          ('chapter_01', 'Mara hid the key beneath the chapel floor.'),
          ('chapter_02', 'Mara told Iven that she hid the key.'),
          ('chapter_03', 'Iven dug beneath the chapel floor.'),
        ]);
        return jsonEncode({
          'events': [for (final e in index.knowledge.events) e.toJson()],
          'answer': index
              .askKnowledge('Who knows Mara hid the key by Chapter 2?')
              .toJson(),
          'leaks': [for (final l in index.knowledgeLeaks()) l.toJson()],
          'version': kStoryPipelineVersion,
        });
      }

      expect(run(), run());
    });
  });

  group('story time', () {
    test(
      '"by Chapter 2" includes its scenes; a scene point does not include later scenes',
      () {
        final index =
            StoryIndex(
                _registry(),
                timeline: StoryTimeline([
                  const TimelineEntry('chapter_01', 'Chapter 1'),
                  const TimelineEntry(
                    'chapter_02_scene_01',
                    'Chapter 2, Scene 1',
                  ),
                  const TimelineEntry(
                    'chapter_02_scene_03',
                    'Chapter 2, Scene 3',
                  ),
                  const TimelineEntry('chapter_03', 'Chapter 3'),
                ]),
              )
              ..ingest('a', 'Edda took the map.', storyTimeId: 'chapter_01')
              ..ingest(
                'b',
                'Mara told Iven that Edda took the map.',
                storyTimeId: 'chapter_02_scene_03',
              );
        expect(
          index
              .askKnowledge('Does Iven know Edda took the map by Chapter 2?')
              .state,
          KnowledgeState.knows,
        );
        expect(
          index
              .askKnowledge(
                'Does Iven know Edda took the map by Chapter 2, Scene 1?',
              )
              .note,
          'first recorded acquisition is later',
        );
        expect(
          index
              .askKnowledge('Does Iven know Edda took the map by Chapter 9?')
              .note,
          'story point not found',
        );
      },
    );

    test('the state is the one at the asked point, not the latest', () {
      final index = _story([
        ('chapter_01', 'Iven believed that the key was under the pier.'),
        ('chapter_03', 'Iven learned that the key was in the barn.'),
      ]);
      expect(
        index
            .askKnowledge(
              'Does Iven know the key was under the pier by Chapter 2?',
            )
            .state,
        KnowledgeState.believes,
      );
      expect(
        index
            .askKnowledge(
              'Does Iven know the key was in the barn by Chapter 3?',
            )
            .state,
        KnowledgeState.knows,
      );
    });

    test('a corrected belief links to the one it replaces', () {
      final events = _story([
        ('chapter_01', 'Iven believed that the key was under the pier.'),
        ('chapter_03', 'Iven learned that the key was in the barn.'),
      ]).knowledge.events.where((e) => e.characterId == 'char_iven').toList();
      final later = events.firstWhere((e) => e.state == KnowledgeState.knows);
      final earlier = events.firstWhere(
        (e) => e.state == KnowledgeState.believes,
      );
      expect(later.supersedes, earlier.id);
      expect(earlier.validUntil, 'chapter_03');
    });
  });

  group('who knows and when', () {
    test('lists who knows at a point, not those who only believe', () {
      final index = _story([
        ('chapter_01', 'Mara hid the key.'),
        ('chapter_02', 'Edda noticed that Mara hid the key.'),
        ('chapter_02', 'Iven believed that Mara hid the key.'),
      ]);
      final a = index.askKnowledge('Who knows Mara hid the key by Chapter 2?');
      expect(a.who.toSet(), {'char_mara', 'char_edda'});
      expect(
        index.askKnowledge('Who knows Mara hid the key by Chapter 1?').who,
        ['char_mara'],
      );
    });

    test('when did they learn names the story point and the passage', () {
      final a = _story([
        ('chapter_01', 'Mara hid the key.'),
        ('chapter_02_scene_04', 'Mara told Iven that she hid the key.'),
      ]).askKnowledge('When did Iven learn that Mara hid the key?');
      expect(a.storyTimeId, 'chapter_02_scene_04');
      expect(a.evidenceSourceIds, {'s2'});
    });

    test('a question that is not understood is UNKNOWN and says so', () {
      final a = _story([
        ('c1', 'Mara hid the key.'),
      ]).askKnowledge('What does Iven think about Mara?');
      expect(a.status, EvidenceStatus.unknown);
      expect(a.note, 'question not understood');
    });
  });

  group('the author\'s own record', () {
    test(
      'is the only way AUTHOR_CONFIRMED_UNAWARE enters, and cites the record',
      () {
        final index = _story([('chapter_01', 'Mara hid the key.')])
          ..addAuthorKnowledge(
            const AuthorKnowledgeRecord(
              recordId: 'note_1',
              characterId: 'char_iven',
              storyTimeId: 'chapter_01',
              state: KnowledgeState.authorConfirmedUnaware,
              text: 'Mara hid the key.',
              note: 'Iven has not been told.',
            ),
          );
        final a = index.askKnowledge('Does Iven know Mara hid the key?');
        expect(a.state, KnowledgeState.authorConfirmedUnaware);
        expect(a.route, AcquisitionRoute.authorEntered);
        expect(a.evidence.single.kind, 'author_record');
        expect(a.evidence.single.sourceId, 'note_1');
      },
    );
  });

  group('possible knowledge leaks', () {
    test(
      'acting on a hidden thing before learning of it is a review item with both passages',
      () {
        final leaks = _story([
          ('chapter_01', 'Mara hid the key beneath the chapel floor.'),
          ('chapter_03', 'Iven dug beneath the chapel floor.'),
          ('chapter_04', 'Mara told Iven that she hid the key.'),
        ]).knowledgeLeaks();
        expect(leaks, hasLength(1));
        final l = leaks.single;
        expect(l.characterId, 'char_iven');
        expect(l.action.quote, 'Iven dug beneath the chapel floor.');
        expect(l.proposition.quote, startsWith('Mara hid the key'));
        expect(l.acquisitionTimeId, 'chapter_04');
        expect(l.toJson()['timeline_order'], [
          'chapter_01',
          'chapter_03',
          'chapter_04',
        ]);
      },
    );

    test(
      'no flag when the character learned first, was the hider, or saw it',
      () {
        expect(
          _story([
            ('c1', 'Mara hid the key beneath the chapel floor.'),
            ('c2', 'Mara told Iven that she hid the key.'),
            ('c3', 'Iven dug beneath the chapel floor.'),
          ]).knowledgeLeaks(),
          isEmpty,
        );
        expect(
          _story([
            ('c1', 'Mara hid the key beneath the chapel floor.'),
            ('c2', 'Mara dug beneath the chapel floor.'),
          ]).knowledgeLeaks(),
          isEmpty,
        );
        expect(
          _story([
            ('c1', 'Mara hid the key beneath the chapel floor.'),
            ('c2', 'Iven saw Mara hide the key.'),
            ('c3', 'Iven dug beneath the chapel floor.'),
          ]).knowledgeLeaks(),
          isEmpty,
        );
      },
    );

    test('no flag when the action comes before the hiding', () {
      expect(
        _story([
          ('c1', 'Iven dug beneath the chapel floor.'),
          ('c2', 'Mara hid the key beneath the chapel floor.'),
        ]).knowledgeLeaks(),
        isEmpty,
      );
    });
  });

  group('the index is derived, never a second source of truth', () {
    test('replacing a passage changes what is known', () {
      final index = _story([
        ('c1', 'Mara hid the key.'),
        ('c2', 'Mara told Iven that she hid the key.'),
      ]);
      expect(
        index.askKnowledge('Does Iven know Mara hid the key?').state,
        KnowledgeState.knows,
      );
      index.remove('s2');
      expect(
        index.askKnowledge('Does Iven know Mara hid the key?').status,
        EvidenceStatus.unknown,
      );
    });

    test(
      'asking a question does not disturb pronoun resolution or numbering',
      () {
        final index = _story([('c1', 'Mara hid the key.')]);
        index.askKnowledge('Does Iven know Edda hid the key?');
        final facts = index.ingest(
          's2',
          'She dropped the key.',
          storyTimeId: 'c1',
        );
        expect(facts.single.subject, 'char_mara');
        expect(facts.single.factId, 's2_f1');
      },
    );

    test('events serialise with source ids and the stated status', () {
      final e = _story([
        ('c1', 'Mara told Iven that Edda stole the ledger.'),
      ]).knowledge.events.single;
      final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>;
      expect(json['knowledge_state'], 'BELIEVES');
      expect(json['acquisition_route'], 'TOLD');
      expect(json['status'], 'STATED');
      expect(json['evidence_refs'], ['s1']);
    });
  });

  group('the development corpus', () {
    test('every question and leak check is answered as the corpus says', () {
      final wrong = <String>[];
      for (final line in File(
        'corpus/knowledge_v1/dev.jsonl',
      ).readAsLinesSync()) {
        final r = jsonDecode(line) as Map<String, dynamic>;
        final registry = EntityRegistry([
          for (final e in r['project_entities'] as List)
            ProjectEntity.fromJson(e as Map<String, dynamic>),
        ]);
        final index = StoryIndex(
          registry,
          timeline: StoryTimeline([
            for (final t in r['timeline'] as List)
              TimelineEntry(t['id'] as String, t['label'] as String),
          ]),
        );
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
        final q = r['query'] as Map<String, dynamic>;
        final want = r['expected'] as Map<String, dynamic>;
        if (q['kind'] == 'leak_check') {
          final got = {
            for (final l in index.knowledgeLeaks())
              '${l.characterId}|${l.action.sourceId}|${l.proposition.sourceId}',
          };
          final exp = {
            for (final l in want['leaks'] as List)
              '${l['character_id']}|${l['action_source_id']}|${l['proposition_source_id']}',
          };
          if (got.length != exp.length || !got.containsAll(exp)) {
            wrong.add(r['record_id'] as String);
          }
          continue;
        }
        final a = index.askKnowledge(q['text'] as String);
        final ev = {...(want['evidence_ids'] as List).cast<String>()};
        final ok =
            a.status.label == want['status'] &&
            a.evidenceSourceIds.length == ev.length &&
            a.evidenceSourceIds.containsAll(ev) &&
            switch (q['kind']) {
              'knows' =>
                a.state?.label == want['knowledge_state'] &&
                    a.route?.label == want['acquisition_route'],
              'who_knows' =>
                a.who.toSet().length == (want['who'] as List).length &&
                    a.who.toSet().containsAll(
                      (want['who'] as List).cast<String>(),
                    ),
              _ => a.storyTimeId == want['story_time_id'],
            };
        if (!ok) wrong.add(r['record_id'] as String);
      }
      expect(wrong, isEmpty);
    });
  });
}
