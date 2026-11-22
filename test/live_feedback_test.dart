/// What the author tells a character about how they answer, and how it shapes the next
/// answers. Feedback is about manner, never facts, and never canon.
library;

import 'package:authoros_language/authoros_language.dart';
import 'package:test/test.dart';

LiveFeedback fb(
  String id, {
  String who = 'mara',
  FeedbackRating rating = FeedbackRating.good,
  String said = 'Why the sea?',
  String spoke = 'It keeps its own counsel.',
  String? note,
  int minute = 0,
}) => LiveFeedback(
  id: id,
  characterId: who,
  at: DateTime.utc(2026, 11, 22, 1, minute),
  rating: rating,
  authorText: said,
  characterText: spoke,
  note: note,
);

LiveTurnInput input({
  FeedbackGuidance guidance = FeedbackGuidance.none,
  String? ask,
  String? question,
  bool asked = false,
}) => LiveTurnInput(
  characterName: 'Mara',
  authorText: ask,
  guidance: guidance,
  directive: LiveDirective(
    behaviour: RelationshipBehaviour.trust,
    question: question,
    authorAsked: asked,
  ),
);

void main() {
  group('feedback record', () {
    test('survives a round trip', () {
      final f = fb('a', rating: FeedbackRating.notQuite, note: ' shorter ');
      final back = LiveFeedback.fromJson(f.toJson())!;
      expect(back.id, 'a');
      expect(back.rating, FeedbackRating.notQuite);
      expect(back.note, 'shorter');
      expect(back.at, f.at);
    });

    test('is read tolerantly: junk is not feedback', () {
      expect(LiveFeedback.fromJson(null), isNull);
      expect(LiveFeedback.fromJson('x'), isNull);
      expect(LiveFeedback.fromJson({'id': 'a'}), isNull);
      final good = fb('a').toJson();
      expect(LiveFeedback.fromJson({...good, 'rating': 'loved'}), isNull);
      expect(LiveFeedback.fromJson({...good, 'at': 'yesterday'}), isNull);
      expect(LiveFeedback.fromJson({...good, 'characterText': '  '}), isNull);
      expect(LiveFeedback.fromJson({...good, 'note': 5})!.note, isNull);
    });
  });

  group('guidance', () {
    test('is this character\'s, newest first, and bounded', () {
      final all = [
        for (var i = 0; i < 6; i++) fb('g$i', minute: i, spoke: 'good $i'),
        for (var i = 0; i < 6; i++)
          fb(
            'n$i',
            rating: FeedbackRating.notQuite,
            minute: 10 + i,
            note: 'fix $i',
          ),
        fb('other', who: 'iven', spoke: 'not mara'),
      ];
      final g = FeedbackGuidance.from(all, 'mara');
      expect(g.liked.map((l) => l.characterText), [
        'good 5',
        'good 4',
        'good 3',
      ]);
      expect(g.corrections.map((c) => c.wanted), [
        'fix 5',
        'fix 4',
        'fix 3',
        'fix 2',
      ]);
      expect(g.allText, isNot(contains('not mara')));
    });

    test('is empty without feedback, and long text is clipped', () {
      expect(FeedbackGuidance.from(const [], 'mara').isEmpty, isTrue);
      final long = fb('a', spoke: 'word ' * 200);
      expect(
        FeedbackGuidance.from([long], 'mara').liked.single.characterText.length,
        lessThan(300),
      );
    });
  });

  group('prompt', () {
    test('says nothing about feedback when there is none', () {
      expect(
        LivePrompt.system(input()),
        isNot(contains('has told you about how')),
      );
    });

    test(
      'puts liked answers and corrections in, as manner and never facts',
      () {
        final g = FeedbackGuidance.from([
          fb('a', spoke: 'Dry and short.'),
          fb(
            'b',
            rating: FeedbackRating.notQuite,
            said: 'Are you afraid?',
            spoke: 'Yes, terribly.',
            note: 'deflect instead of admitting it',
            minute: 5,
          ),
        ], 'mara');
        final p = LivePrompt.system(input(guidance: g));
        expect(
          p,
          contains('What the author has told you about how you answer'),
        );
        expect(p, contains('never about what is true'));
        expect(p, contains('Dry and short.'));
        expect(p, contains('Yes, terribly.'));
        expect(p, contains('They wanted: deflect instead of admitting it'));
      },
    );

    test('a "not quite" with no note still says so', () {
      final g = FeedbackGuidance.from([
        fb('b', rating: FeedbackRating.notQuite),
      ], 'mara');
      expect(
        LivePrompt.system(input(guidance: g)),
        contains('not quite right'),
      );
    });

    test('tells the character to answer a question first', () {
      expect(LivePrompt.system(input()), contains('answer it first'));
    });
  });

  group('guard', () {
    const guard = LiveGuard();

    test('a name the author used in feedback may be said back', () {
      final g = FeedbackGuidance.from([
        fb('a', spoke: 'Ask Tobias, he knows the harbour.'),
      ], 'mara');
      final c = guard.check(
        input(guidance: g, ask: 'Who knows the harbour?'),
        'Tobias knows the harbour, I think.',
      );
      expect(c.ok, isTrue, reason: c.problems.join(','));
    });

    test('a question put to the character must be answered before its own', () {
      final t = input(
        ask: 'How are you today?',
        question: 'What would you say it is?',
        asked: true,
      );
      final only = guard.check(t, 'What would you say it is?');
      expect(only.ok, isFalse);
      expect(only.problems.join(), contains('does not answer'));
      final answered = guard.check(
        t,
        'Restless, if I am honest. What would you say it is?',
      );
      expect(answered.ok, isTrue, reason: answered.problems.join(','));
    });

    test('opening lines and unasked turns are not held to it', () {
      final opening = LiveTurnInput(
        characterName: 'Mara',
        directive: const LiveDirective(
          behaviour: RelationshipBehaviour.trust,
          question: 'What would you do with one ordinary day?',
          opening: true,
          authorAsked: true,
        ),
      );
      expect(
        guard
            .check(opening, 'Hello. What would you do with one ordinary day?')
            .ok,
        isTrue,
      );
      final plain = input(ask: 'Hm.', question: 'What do you want most?');
      expect(
        guard.check(plain, 'Fair enough. What do you want most?').ok,
        isTrue,
      );
    });
  });
}
