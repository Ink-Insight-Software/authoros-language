/// A character who can disagree, and an author who decides.
///
/// Phase 3.7 of the master build plan: detect a proposal that conflicts with what
/// the character holds to, show the evidence, let the author keep their choice,
/// and never present the character's view as higher than the author's.
library;

import 'package:authoros_language/authoros_language.dart';
import 'package:test/test.dart';

const loyal = CharacterCommitment(
  id: 'loyal',
  kind: CommitmentKind.value,
  statement: 'Kali never abandons anyone who trusted her.',
  avoids: {'abandon', 'betray', 'desert'},
  embraces: {'protect', 'stay'},
  weight: CommitmentWeight.core,
);
const afraid = CharacterCommitment(
  id: 'afraid',
  kind: CommitmentKind.fear,
  statement: 'Kali is afraid of fire.',
  avoids: {'fire', 'burn'},
  weight: CommitmentWeight.strong,
);
const mild = CharacterCommitment(
  id: 'mild',
  kind: CommitmentKind.behaviour,
  statement: 'Kali prefers not to drink.',
  avoids: {'drink'},
  weight: CommitmentWeight.mild,
);

AuthorProposal proposal(String text, Set<String> terms) =>
    AuthorProposal(text: text, terms: terms);

void main() {
  const detector = DisagreementDetector();

  group('noticing a conflict', () {
    test('finds a proposal that runs against a commitment', () {
      final found = detector.detect(
        proposal('Kali leaves Vincenzo behind.', {'abandon', 'leaves'}),
        [loyal, afraid],
      );
      expect(found.length, 1);
      expect(found.single.commitment.id, 'loyal');
      expect(found.single.matchedTerms, {'abandon'});
    });

    test('quotes the commitment as the evidence', () {
      final found = detector.detect(proposal('She deserts him.', {'desert'}), [
        loyal,
      ]);
      expect(
        found.single.evidence,
        'Kali never abandons anyone who trusted her.',
      );
    });

    test('finds nothing when the proposal stands clear of everything', () {
      expect(
        detector.detect(proposal('Kali makes tea.', {'tea', 'kettle'}), [
          loyal,
          afraid,
        ]),
        isEmpty,
      );
    });

    test('matches a word and its stem', () {
      expect(
        detector.detect(proposal('A betrayal.', {'betrayal'}), [loyal]),
        isNotEmpty,
      );
      expect(
        detector.detect(proposal('Abandoning him.', {'abandoning'}), [loyal]),
        isNotEmpty,
      );
    });

    test('does not match unrelated short words', () {
      expect(detector.detect(proposal('x', {'fir', 'bur'}), [afraid]), isEmpty);
    });

    test('ignores case and surrounding space', () {
      expect(
        detector.detect(proposal('x', {'  ABANDON '}), [loyal]),
        isNotEmpty,
      );
    });
  });

  group('how strongly', () {
    test('a core commitment speaks louder than a mild one', () {
      final core = detector
          .detect(proposal('x', {'abandon'}), [loyal])
          .single
          .strength;
      final light = detector.detect(proposal('x', {'drink'}), [mild]).isEmpty;
      expect(core, greaterThan(0.4));
      expect(
        light,
        isTrue,
        reason: 'one hint against a mild commitment is not worth raising',
      );
    });

    test('more matching terms is a pattern, and stronger', () {
      final one = detector.detect(proposal('x', {'abandon'}), [loyal]).single;
      final two = detector.detect(proposal('x', {'abandon', 'betray'}), [
        loyal,
      ]).single;
      expect(two.strength, greaterThan(one.strength));
    });

    test(
      'is softer when the proposal also uses what the character stands for',
      () {
        final plain = detector.detect(proposal('x', {'abandon', 'betray'}), [
          loyal,
        ]).single;
        final mixed = detector.detect(
          proposal('x', {'abandon', 'betray', 'protect'}),
          [loyal],
        ).single;
        expect(mixed.strength, lessThan(plain.strength));
      },
    );

    test('a single hint that cuts both ways is not worth raising', () {
      expect(
        detector.detect(proposal('x', {'abandon', 'protect'}), [loyal]),
        isEmpty,
        reason: 'one term against, one for: no clear conflict to raise',
      );
    });

    test('lists the strongest first', () {
      final found = detector.detect(proposal('x', {'abandon', 'fire'}), [
        afraid,
        loyal,
      ]);
      expect([for (final d in found) d.commitment.id], ['loyal', 'afraid']);
    });

    test('keeps strength within zero and one', () {
      final found = detector.detect(
        proposal('x', {'abandon', 'betray', 'desert'}),
        [loyal],
      );
      expect(found.single.strength, inInclusiveRange(0.0, 1.0));
    });
  });

  group('the author decides', () {
    test(
      'every way a disagreement can end is the author\'s act, or kept open',
      () {
        expect(
          {for (final r in DisagreementResolution.values) r.name},
          {
            'open',
            'authorKept',
            'authorReconsidered',
            'keptAsThread',
            'becameDiscovery',
            'becameContradiction',
          },
        );
        for (final r in DisagreementResolution.values) {
          expect(
            r.name.toLowerCase(),
            isNot(contains('character')),
            reason: 'no resolution has the character prevailing',
          );
          expect(r.name.toLowerCase(), isNot(contains('overrule')));
        }
      },
    );

    test('a disagreement can be settled, and is open until it is', () {
      final record = DisagreementRecord(
        id: 'd1',
        commitmentId: 'loyal',
        proposalText: 'Kali leaves him.',
        at: DateTime.utc(2026, 10, 5),
        sessionId: 's1',
      );
      expect(record.isSettled, isFalse);
      final kept = record.resolved(DisagreementResolution.authorKept);
      expect(kept.isSettled, isTrue);
      expect(kept.resolution, DisagreementResolution.authorKept);
      expect(
        record.resolution,
        DisagreementResolution.open,
        reason: 'a record is a value',
      );
    });

    test('can become a discovery or a contradiction thread', () {
      final record = DisagreementRecord(
        id: 'd',
        commitmentId: 'c',
        proposalText: 'x',
        at: DateTime.utc(2026),
      );
      expect(
        record.resolved(DisagreementResolution.becameDiscovery).isSettled,
        isTrue,
      );
      expect(
        record.resolved(DisagreementResolution.becameContradiction).isSettled,
        isTrue,
      );
    });

    test('keeps the author\'s words as they said them', () {
      final p = proposal('She walks away without a word.', {'abandon'});
      expect(p.text, 'She walks away without a word.');
    });
  });
}
