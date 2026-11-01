/// Checks what the model said before anyone sees it. A reply that fails is thrown
/// away and the authored line is used instead, so what an author reads is either
/// checked or authored, never unchecked.
///
/// The rules are the ones the training lines are held to (`model/authoring.py`, and
/// the writing screen): one short plain line, no names, places or numbers, no
/// markup or quotation marks. Plus one that only a reply can break: not just the
/// author's own words handed back. They are kept in step by one shared case list
/// (`model/writer/rule_cases.json`) that all three implementations must judge alike.
library;

import 'chat_models.dart';

class ChatGuard {
  const ChatGuard({this.maxWords = 30});

  final int maxWords;

  static final _markup = RegExp(
    r'[*#`_>|\[\]{}<>\\]|^\s*[-•]\s',
    multiLine: true,
  );
  static final _digit = RegExp(r'\d');
  static final _quotes = RegExp('["“”]');
  static final _titles = RegExp(
    r'\b(?:Mr|Mrs|Miss|Ms|Dr|Sir|Madam|Lady|Lord)\b\.?',
  );
  static final _word = RegExp(r"[A-Za-z][A-Za-z'’-]*");
  static final _newline = RegExp(r'[\r\n]');

  /// Capitalised words that do not begin a sentence, apart from "I": a name.
  static List<String> midSentenceCapitals(String text) {
    final out = <String>[];
    for (final m in _word.allMatches(text)) {
      final w = m.group(0)!;
      if (w == 'I' || w.startsWith("I'") || w.startsWith('I’')) continue;
      if (w[0] == w[0].toLowerCase()) continue;
      final head = text.substring(0, m.start).trimRight();
      if (head.isEmpty ||
          RegExp(r'[.!?…]$').hasMatch(head) ||
          RegExp('(?:—|-|"|“)\$').hasMatch(head)) {
        continue;
      }
      out.add(w);
    }
    return out;
  }

  /// What is wrong with [text] as a line of speech, whoever said it. Empty if
  /// nothing. [allowed] are words the author used, which may be said back.
  List<String> problems(String text, {Set<String> allowed = const {}}) {
    final t = text.trim();
    if (t.isEmpty) return const ['empty'];
    final bad = <String>[];
    if (_newline.hasMatch(text.trim())) bad.add('more than one line');
    final words = t.split(RegExp(r'\s+')).length;
    if (words > maxWords) bad.add('$words words, over $maxWords');
    if (_markup.hasMatch(t)) bad.add('markup or a list marker');
    if (_digit.hasMatch(t)) bad.add('a digit');
    if (_quotes.hasMatch(t)) bad.add('quotation marks');
    final names = [
      for (final w in midSentenceCapitals(t))
        if (!allowed.contains(w.toLowerCase())) w,
    ];
    if (_titles.hasMatch(t) || names.isNotEmpty) {
      bad.add('names someone or somewhere');
    }
    return bad;
  }

  static String _plain(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// The line, or null with the first reason it was refused.
  ({String? text, String? reason}) check(ChatRequest request, String reply) {
    final line = reply.trim();
    final author = request.authorLine;
    final allowed = {
      for (final m in _word.allMatches(author)) m.group(0)!.toLowerCase(),
    };
    final bad = problems(line, allowed: allowed);
    if (bad.isNotEmpty) return (text: null, reason: bad.first);
    if (author.trim().isNotEmpty && _plain(line) == _plain(author)) {
      return (text: null, reason: 'only repeats the author');
    }
    return (text: line, reason: null);
  }
}
