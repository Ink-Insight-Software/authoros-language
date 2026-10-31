/// Splits a source into sentences and words, keeping every character offset valid.
///
/// Contractions are split the way Universal Dependencies does: `didn't` is `did` and
/// `n't`, `Duke's` is `Duke` and `'s`. Quotation marks and other punctuation are
/// tokens of their own. Nothing is rewritten, so `text.substring(start, end)` of a
/// token is always the token.
library;

import 'labels.dart';

class StoryTokenizer {
  const StoryTokenizer();

  static const _abbreviations = {
    'mr',
    'mrs',
    'ms',
    'dr',
    'st',
    'mt',
    'sr',
    'jr',
    'vs',
    'etc',
    'prof',
    'capt',
    'col',
    'gen',
    'lt',
    'sgt',
    'no',
    'fig',
  };

  static final _word = RegExp(
    r"\d+(?:[.,]\d+)*|[A-Za-z]+(?:-[A-Za-z]+)*(?:['’][A-Za-z]+)?|\.\.\.|…|--|—|\S",
  );
  static final _clitic = RegExp(
    r"^([A-Za-z]+(?:-[A-Za-z]+)*)(n['’]t|['’](?:s|ll|d|ve|re|m))$",
    caseSensitive: false,
  );

  /// The sentences of [text], each with its tokens (no tags yet).
  List<Sentence> tokenize(String text) {
    final spans = _sentenceSpans(text);
    return [
      for (final (start, end) in spans)
        Sentence(
          start: start,
          end: end,
          text: text.substring(start, end),
          tokens: _tokens(text, start, end),
        ),
    ];
  }

  List<(int, int)> _sentenceSpans(String text) {
    final out = <(int, int)>[];
    var start = 0;
    while (start < text.length && _isSpace(text[start])) {
      start++;
    }
    var i = start;
    while (i < text.length) {
      final c = text[i];
      if (c == '.' || c == '!' || c == '?' || c == '…') {
        // The end of the run of terminal marks and closing quotes after it.
        var j = i + 1;
        while (j < text.length && '.!?…'.contains(text[j])) {
          j++;
        }
        while (j < text.length && '"”’\')]'.contains(text[j])) {
          j++;
        }
        if (_endsSentence(text, i, j)) {
          out.add((start, j));
          start = j;
          while (start < text.length && _isSpace(text[start])) {
            start++;
          }
          i = start;
          continue;
        }
        i = j;
        continue;
      }
      i++;
    }
    if (start < text.length && text.substring(start).trim().isNotEmpty) {
      out.add((start, text.trimRight().length));
    }
    return out;
  }

  bool _endsSentence(String text, int mark, int after) {
    if (text[mark] == '.') {
      // An abbreviation or an initial: "Mr. Hale", "J. Hale".
      var k = mark;
      while (k > 0 && RegExp(r'[A-Za-z]').hasMatch(text[k - 1])) {
        k--;
      }
      final word = text.substring(k, mark).toLowerCase();
      if (_abbreviations.contains(word) || (word.length == 1 && k < mark)) {
        return false;
      }
    }
    if (after >= text.length) return true;
    var n = after;
    if (!_isSpace(text[n])) return false;
    while (n < text.length && _isSpace(text[n])) {
      n++;
    }
    if (n >= text.length) return true;
    // A new sentence starts with a capital or an opening quote.
    return RegExp('[A-Z“"‘\'0-9]').hasMatch(text[n]);
  }

  static bool _isSpace(String c) => c.trim().isEmpty;

  List<Token> _tokens(String text, int start, int end) {
    final out = <Token>[];
    for (final m in _word.allMatches(text.substring(start, end))) {
      final s = start + m.start;
      final w = m.group(0)!;
      final c = _clitic.firstMatch(w);
      if (c != null) {
        final stem = c.group(1)!;
        var tail = c.group(2)!;
        var head = stem;
        // "can't" is "ca" + "n't" in UD; "won't" is "wo" + "n't".
        if (tail.toLowerCase().startsWith('n')) {
          head = stem;
        }
        out.add(Token(text: head, start: s, end: s + head.length));
        out.add(Token(text: tail, start: s + head.length, end: s + w.length));
        continue;
      }
      out.add(Token(text: w, start: s, end: s + w.length));
    }
    return out;
  }
}
