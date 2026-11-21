/// Checks a live reply before anyone reads it. A reply that fails is retried once and
/// then replaced by the engine's own wording, so what an author reads is either checked
/// or authored, never raw model output.
library;

import '../voice/relationship_behaviour.dart' show RelationshipBehaviour;
import '../voice/voice_profile.dart';
import 'live_models.dart';

class LiveCheck {
  const LiveCheck({
    required this.text,
    this.problems = const [],
    this.introduced = const [],
  });

  /// The reply, tidied (wrapping quotes removed, spacing normalised).
  final String text;

  /// Why the reply cannot be used. Empty: it can.
  final List<String> problems;

  /// Names the reply brings in that the story does not hold. A problem in canon; just
  /// reported in a what-if conversation.
  final List<String> introduced;

  bool get ok => problems.isEmpty;
}

class LiveGuard {
  const LiveGuard();

  static final _markup = RegExp(
    r'[*#`_|\[\]{}<>\\]|^\s*(?:[-•]|\d+[.)])\s',
    multiLine: true,
  );
  static final _emoji = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F000}-\u{1F2FF}]',
    unicode: true,
  );
  static final _meta = RegExp(
    r"\b(?:as an ai|i am an ai|i'm an ai|language model|artificial intelligence|"
    r"system prompt|my instructions|my prompt|i(?: am|'m) (?:just )?programmed|"
    r'anthropic|openai|chatgpt|claude)\b',
    caseSensitive: false,
  );
  static final _word = RegExp(r"[A-Za-z][A-Za-z'’-]*");
  static final _sentenceEnd = RegExp(r'[.!?…]["”’)]*$');

  static int maxWords(CommunicationLength l) => switch (l) {
    CommunicationLength.terse => 45,
    CommunicationLength.measured => 85,
    CommunicationLength.expansive => 150,
  };

  /// Capitalised words that do not start a sentence, apart from "I".
  static List<String> names(String text) {
    final out = <String>[];
    for (final m in _word.allMatches(text)) {
      final w = m.group(0)!;
      if (w == 'I' || w.startsWith("I'") || w.startsWith('I’')) continue;
      if (w[0] == w[0].toLowerCase()) continue;
      final head = text.substring(0, m.start).trimRight();
      if (head.isEmpty ||
          RegExp(r'[.!?…:]$').hasMatch(head) ||
          RegExp('(?:—|–|"|“|‘|\')\$').hasMatch(head)) {
        continue;
      }
      out.add(w);
    }
    return out;
  }

  static String _plain(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static Set<String> _tokens(String s) => {
    for (final m in RegExp(r'[a-z0-9]+').allMatches(s.toLowerCase()))
      if (m.group(0)!.length > 2) m.group(0)!,
  };

  static double _overlap(String a, String b) {
    final x = _tokens(a), y = _tokens(b);
    if (x.isEmpty || y.isEmpty) return 0;
    return x.intersection(y).length / x.union(y).length;
  }

  /// Words the character may say: whatever the prompt and the author put in front of
  /// them. Anything else that looks like a name was made up.
  static Set<String> allowedNames(LiveTurnInput input) {
    final text = StringBuffer()
      ..writeln(input.characterName)
      ..writeln(input.authorName ?? '')
      ..writeln(input.sceneTitle ?? '')
      ..writeln(input.authorText ?? '')
      ..writeln(input.directive.question ?? '')
      ..writeln(input.directive.draft.join('\n'))
      ..writeln(input.summary ?? '')
      ..writeln(input.epithet ?? '')
      ..writeln(input.roles ?? '');
    for (final f in input.facts) {
      text.writeln(f.text);
    }
    for (final f in input.storyFacts) {
      text.writeln(f.text);
    }
    for (final l in input.history) {
      text.writeln(l.text);
    }
    return {
      for (final m in _word.allMatches(text.toString()))
        m.group(0)!.toLowerCase(),
    };
  }

  LiveCheck check(LiveTurnInput input, String raw) {
    var t = raw.replaceAll('\r', '').trim();
    // A model sometimes wraps the whole line in quotation marks. That is not a fault.
    final wrapped = RegExp(r'^["“](.*)["”]$', dotAll: true).firstMatch(t);
    if (wrapped != null && !wrapped.group(1)!.contains(RegExp('["“”]'))) {
      t = wrapped.group(1)!.trim();
    }
    t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
    final bad = <String>[];
    if (t.isEmpty) return const LiveCheck(text: '', problems: ['empty']);

    final words = t.split(RegExp(r'\s+')).length;
    final limit = maxWords(input.length);
    if (words > limit) bad.add('$words words, over $limit');
    if (_markup.hasMatch(t)) bad.add('markup or a list');
    if (_emoji.hasMatch(t)) bad.add('an emoji');
    if (_meta.hasMatch(t)) bad.add('talks about being a model');
    if (RegExp(r'\n\s*\n').hasMatch(t) &&
        input.length != CommunicationLength.expansive) {
      bad.add('more than one paragraph');
    }
    if (!_sentenceEnd.hasMatch(t) && !t.endsWith('—') && !t.endsWith('-')) {
      bad.add('cut off mid-sentence');
    }

    final d = input.directive;
    final marks = '?'.allMatches(t).length;
    final q = d.question;
    if (q != null) {
      final tail = _plain(t);
      if (!tail.endsWith(_plain(q))) {
        bad.add('does not end with the decided question, unchanged');
      } else if (marks > 1) {
        bad.add('asks more than the one question');
      }
    } else {
      final lively = switch (d.behaviour) {
        RelationshipBehaviour.challenge ||
        RelationshipBehaviour.deflect ||
        RelationshipBehaviour.tease ||
        RelationshipBehaviour.refuse ||
        RelationshipBehaviour.humour => true,
        _ => false,
      };
      if (d.closes && marks > 0) bad.add('asks a question while closing');
      if (!lively && marks > 0) bad.add('asks a question it was not given');
      if (marks > 1) bad.add('asks more than one question');
    }

    // Not the author's own words handed back, and not a repeat of an earlier line.
    final said = input.authorText?.trim();
    if (said != null && said.length > 20 && _overlap(said, t) > 0.8) {
      bad.add('just repeats the author');
    }
    for (final l in input.history) {
      if (l.speaker == LiveSpeaker.character &&
          l.text.trim().length > 12 &&
          _overlap(l.text, t) > 0.75) {
        bad.add('repeats an earlier line');
        break;
      }
    }

    final allowed = allowedNames(input);
    final made = <String>{
      for (final w in names(t))
        if (!allowed.contains(w.toLowerCase())) w,
    };
    final introduced = made.toList();
    if (made.isNotEmpty && input.mode == LiveMode.canon) {
      bad.add(
        'names someone or somewhere the story does not: ${made.join(', ')}',
      );
    }
    return LiveCheck(text: t, problems: bad, introduced: introduced);
  }
}
