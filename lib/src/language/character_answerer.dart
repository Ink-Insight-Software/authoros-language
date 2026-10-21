/// A character answering a question the author puts to them (plan 2.9: *handle
/// questions directed back to the character*).
///
/// A character may only say what is **known**: what the author wrote about them in
/// the project, and what the author has confirmed in conversation. It never makes
/// something up to be helpful, because anything it said might be taken for canon.
/// When it does not know, it says so and hands the question back, which is also
/// what a real person does.
///
/// Tender facts (what they fear) are held back from someone they have only just met,
/// the same boundary the rest of the character's behaviour keeps.
library;

import 'package:authoros_core/procedural/generation_seed.dart';

import '../questions/relationship_stage.dart';
import '../voice/voice_profile.dart';

/// What kind of thing a known fact is.
enum FactTopic { identity, summary, trait, fear, want }

/// One thing the character knows about themselves. [text] is the author's own words.
class KnownFact {
  const KnownFact(this.topic, this.text, {this.tender = false});

  final FactTopic topic;
  final String text;

  /// Held back until the character knows the author a little.
  final bool tender;
}

/// What the author asked about, as far as a plain reading can tell.
enum AskedAbout { who, fear, want, feel, think, like, unknown }

class CharacterAnswer {
  const CharacterAnswer({
    required this.lines,
    this.used = const [],
    this.asked = AskedAbout.unknown,
    this.asksBack = false,
    this.offered = false,
  });

  final List<String> lines;

  /// The facts spoken, always a subset of what was passed in.
  final List<KnownFact> used;
  final AskedAbout asked;

  /// The answer ends by handing a question to the author ("Does that fit?"), so it
  /// is the whole of the reply: the character does not pile another question on it.
  final bool asksBack;

  /// What was said is a guess from what the author wrote, offered as one, and is
  /// not something the author has said is true.
  final bool offered;

  bool get knew => used.isNotEmpty;
}

class AnswerRequest {
  const AnswerRequest({
    required this.question,
    required this.facts,
    required this.stage,
    required this.tone,
    required this.seed,
    required this.turn,
  });

  final String question;
  final List<KnownFact> facts;
  final RelationshipStage stage;
  final VoiceTone tone;
  final GenerationSeed seed;
  final int turn;
}

abstract interface class CharacterAnswerer {
  CharacterAnswer answer(AnswerRequest request);
}

class RuleBasedAnswerer implements CharacterAnswerer {
  const RuleBasedAnswerer();

  static final _fear = RegExp(
    r'\b(afraid|fears?|scared|terrif\w*|frighten\w*|dread\w*)\b',
  );
  static final _want = RegExp(
    r'\b(want|wants|wish|wishes|hope|hopes|dream|dreams|goal|goals|aim|ambition)\b',
  );
  static final _who = RegExp(
    r"\b(who are you|about yourself|describe yourself|tell me about you|what are you like|"
    r"what do you do|what's your role|what is your role|your job)\b",
  );

  /// Whether the author is plainly asking, rather than writing a sentence that
  /// happens to contain a question mark.
  static bool isDirectQuestion(String text) {
    final t = text.trim();
    if (!t.endsWith('?')) return false;
    return t.split(RegExp(r'\s+')).length <= 20;
  }

  static final _feel = RegExp(
    r"\b(feel|felt|feeling|feelings|how did (?:it|that) (?:feel|go)|how are you)\b",
  );
  static final _think = RegExp(r'\b(think|thought|believe|opinion|reckon)\b');
  static final _like = RegExp(
    r'\b(like|likes|love|enjoy|prefer|favourite|favorite)\b',
  );

  static AskedAbout classify(String question) {
    final q = question.toLowerCase();
    if (_fear.hasMatch(q)) return AskedAbout.fear;
    if (_who.hasMatch(q)) return AskedAbout.who;
    if (_want.hasMatch(q)) return AskedAbout.want;
    if (_feel.hasMatch(q)) return AskedAbout.feel;
    if (_think.hasMatch(q)) return AskedAbout.think;
    if (_like.hasMatch(q)) return AskedAbout.like;
    return AskedAbout.unknown;
  }

  static const _leads = {
    VoiceTone.warm: "From what you've written about me:",
    VoiceTone.gentle: "From what you've written about me:",
    VoiceTone.earnest: "From what you've written about me:",
    VoiceTone.neutral: "As I'm written:",
    VoiceTone.formal: "As I am written:",
    VoiceTone.dry: "Since you wrote me:",
    VoiceTone.sardonic: "Since you wrote me:",
    VoiceTone.blunt: "Since you wrote me:",
    VoiceTone.timid: "From what you wrote about me... I think:",
    VoiceTone.quiet: 'As written:',
    VoiceTone.playful: "Well, according to the person who wrote me:",
    VoiceTone.stoic: 'As I am written:',
  };

  static const _hold = {
    'soft': [
      "That's not something I tell someone I've only just met.",
      "I'd rather not say that yet. Ask me again when we know each other better.",
    ],
    'neutral': [
      'That is not something I discuss with someone I have only just met.',
      'Ask me that when we know each other better.',
    ],
    'sharp': [
      "That's not for strangers.",
      "Earn that one. Ask me again later.",
    ],
  };

  static const _unknown = {
    'soft': [
      "I don't know that yet. You haven't told me. What do you think?",
      "That's not something I've been given. What would you say?",
    ],
    'neutral': [
      'I do not know that. You have not told me. What do you think?',
      'That is not something I have been given. What would you say?',
    ],
    'sharp': [
      "Don't ask me. You're the author. What do you think?",
      "You haven't told me. You first.",
    ],
  };

  /// What the author asked about, said as what is not yet written.
  static const _unwritten = <String, Map<AskedAbout, String>>{
    'soft': {
      AskedAbout.feel: "How I felt isn't something you've written yet.",
      AskedAbout.think:
          "What I think about that isn't something you've written yet.",
      AskedAbout.like: "What I like isn't something you've written yet.",
      AskedAbout.who: "Who I am isn't something you've written yet.",
      AskedAbout.fear: "What I fear isn't something you've written yet.",
      AskedAbout.want: "What I want isn't something you've written yet.",
    },
    'neutral': {
      AskedAbout.feel: 'How I felt is not something you have written yet.',
      AskedAbout.think:
          'What I think about that is not something you have written yet.',
      AskedAbout.like: 'What I like is not something you have written yet.',
      AskedAbout.who: 'Who I am is not something you have written yet.',
      AskedAbout.fear: 'What I fear is not something you have written yet.',
      AskedAbout.want: 'What I want is not something you have written yet.',
    },
    'sharp': {
      AskedAbout.feel: "You haven't written how I felt.",
      AskedAbout.think: "You haven't written what I think.",
      AskedAbout.like: "You haven't written what I like.",
      AskedAbout.who: "You haven't written who I am.",
      AskedAbout.fear: "You haven't written what I fear.",
      AskedAbout.want: "You haven't written what I want.",
    },
  };

  /// What a character says to hand the question back when it has nothing written
  /// to answer from.
  static const _handBack = {
    'soft': [
      'If you had to say, what would it be?',
      'What would you want it to be?',
    ],
    'neutral': [
      'If you had to say, what would it be?',
      'What would you say it is?',
    ],
    'sharp': ['You first. What would it be?', 'So tell me. What is it?'],
  };

  /// What a character says when it can only offer a guess from how it was written.
  /// `{fact}` is the author's own words about the character.
  static const _offer = {
    'soft': [
      'From how you wrote me ({fact}), I would start there. Does that fit?',
      'Going by what you wrote ({fact}), is that close?',
    ],
    'neutral': [
      'Going by how I am written ({fact}), I would start there. Does that fit?',
      'From what you wrote ({fact}), is that close?',
    ],
    'sharp': [
      'You wrote me this way ({fact}). Start there. Does it fit?',
      'On what you wrote ({fact}), close?',
    ],
  };

  /// Every phrase this can say besides the author's own words, for auditing.
  static Set<String> get phrases => {
    ..._leads.values,
    for (final pool in _hold.values) ...pool,
    for (final pool in _unknown.values) ...pool,
    for (final bank in _unwritten.values) ...bank.values,
    for (final pool in _handBack.values) ...pool,
    for (final pool in _offer.values) ...pool,
  };

  static final List<RegExp> _patterns = [
    for (final p in phrases)
      RegExp(
        '^${p.splitMapJoin(RegExp(r'\{\w+\}'), onMatch: (_) => '\u0000', onNonMatch: RegExp.escape).replaceAll('\u0000', '(.+?)')}\$',
      ),
  ];

  /// Whether [line] is one of this answerer's stock lines, with the author's words
  /// in its slot. For auditing.
  static bool isStock(String line) =>
      phrases.contains(line) || _patterns.any((p) => p.hasMatch(line));

  static String _toneKey(VoiceTone t) => switch (t) {
    VoiceTone.warm || VoiceTone.gentle || VoiceTone.earnest => 'soft',
    VoiceTone.neutral || VoiceTone.formal || VoiceTone.stoic => 'neutral',
    VoiceTone.timid || VoiceTone.quiet => 'soft',
    _ => 'sharp',
  };

  @override
  CharacterAnswer answer(AnswerRequest r) {
    final asked = classify(r.question);
    final key = _toneKey(r.tone);
    String pick(List<String> pool, String id) {
      final roll = r.seed.derive('answer/$id').unitAt(r.turn, pool.length);
      return pool[(roll * pool.length).floor().clamp(0, pool.length - 1)];
    }

    final wanted = switch (asked) {
      AskedAbout.who => {
        FactTopic.identity,
        FactTopic.summary,
        FactTopic.trait,
      },
      AskedAbout.fear => {FactTopic.fear},
      AskedAbout.want => {FactTopic.want},
      _ => <FactTopic>{},
    };
    final matching = [
      for (final f in r.facts)
        if (wanted.contains(f.topic)) f,
    ];
    if (matching.isEmpty) {
      final shownFacts = [
        for (final f in r.facts)
          if (!f.tender || r.stage.index >= RelationshipStage.familiar.index) f,
      ];
      // What the character may offer as a guess, from how it was written, best
      // suited first. Never as fact, and never anything the author did not write.
      final order = switch (asked) {
        AskedAbout.feel => [FactTopic.fear, FactTopic.trait, FactTopic.summary],
        _ => <FactTopic>[],
      };
      KnownFact? guess;
      for (final topic in order) {
        for (final f in shownFacts) {
          if (f.topic == topic) {
            guess = f;
            break;
          }
        }
        if (guess != null) break;
      }
      final unwritten = _unwritten[key]![asked];
      if (guess != null && unwritten != null) {
        final fact = guess.text.replaceFirst(RegExp(r'[.!?]+$'), '');
        return CharacterAnswer(
          lines: [
            unwritten,
            pick(_offer[key]!, 'offer').replaceAll('{fact}', fact),
          ],
          used: [guess],
          asked: asked,
          asksBack: true,
          offered: true,
        );
      }
      if (unwritten != null) {
        return CharacterAnswer(
          lines: [unwritten, pick(_handBack[key]!, 'handback')],
          asked: asked,
          asksBack: true,
        );
      }
      return CharacterAnswer(
        lines: [pick(_unknown[key]!, 'unknown')],
        asked: asked,
        asksBack: true,
      );
    }
    final shown = [
      for (final f in matching)
        if (!f.tender || r.stage.index >= RelationshipStage.familiar.index) f,
    ];
    if (shown.isEmpty) {
      return CharacterAnswer(lines: [pick(_hold[key]!, 'hold')], asked: asked);
    }
    return CharacterAnswer(
      lines: [_leads[r.tone]!, for (final f in shown) f.text],
      used: shown,
      asked: asked,
    );
  }
}
