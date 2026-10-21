/// Checks a model's reply before anything is shown. A reply that fails any check
/// is thrown away and the rule-based line is used instead, so what the author sees
/// is either checked or authored, never unchecked.
///
/// What a check can promise, and what it cannot: it can promise the selected
/// question is intact, that the reply is short and plain, and that it brings in no
/// new name, place or number. It cannot promise that every sentence is true of the
/// story, so the prompt allows no facts but those supplied, and the author reads
/// everything as a suggestion, never as canon.
library;

import '../language/delivery_service.dart';

/// A reply that passed: the words before the question, and the question.
class GuardedReply {
  const GuardedReply(this.before, this.question);

  /// Empty when the character just asks.
  final String before;
  final String question;
}

class DeliveryGuard {
  const DeliveryGuard({this.maxBeforeChars = 360, this.maxSentences = 4});

  final int maxBeforeChars;
  final int maxSentences;

  /// The first reason [reply] is not acceptable, or null with [accepted] set.
  ///
  /// [allowed] is every piece of text the character may repeat words from: the
  /// author's last words, the known facts, the scene title and the character's own
  /// name. The question is added here.
  ({GuardedReply? accepted, String? reason}) check(
    DeliveryRequest r,
    String reply, {
    String? characterName,
    Iterable<String> allowed = const [],
  }) {
    final question = r.question;
    if (question == null) return (accepted: null, reason: 'no question');
    final text = reply.trim();
    if (text.isEmpty) return (accepted: null, reason: 'empty');

    final at = text.indexOf(question);
    if (at < 0) return (accepted: null, reason: 'question changed');
    if (text.indexOf(question, at + 1) >= 0) {
      return (accepted: null, reason: 'question repeated');
    }
    final after = text.substring(at + question.length).trim();
    if (after.isNotEmpty) {
      return (accepted: null, reason: 'text after question');
    }
    final before = text.substring(0, at).trim();

    if (before.length > maxBeforeChars) {
      return (accepted: null, reason: 'too long');
    }
    final sentences = RegExp(r'[.!?…]+(?:\s|$)').allMatches(before).length;
    if (sentences > maxSentences) {
      return (accepted: null, reason: 'too many sentences');
    }
    if (RegExp(
      r'[*#`_>|]|\[|\]|\n\s*\n|^\s*[-•]\s',
      multiLine: true,
    ).hasMatch(before)) {
      return (accepted: null, reason: 'formatting');
    }
    if (RegExp(r'^\s*(?:[\w ]{1,30}:|"|“)').hasMatch(before)) {
      return (accepted: null, reason: 'label or quotation');
    }

    final known = _tokens([
      question,
      r.lastAuthorText ?? '',
      ...r.knownFacts,
      r.sceneTitle ?? '',
      characterName ?? '',
      ...allowed,
    ]);
    final invented = _newNames(before, known);
    if (invented.isNotEmpty) {
      return (accepted: null, reason: 'new name or number: ${invented.first}');
    }
    return (accepted: GuardedReply(before, question), reason: null);
  }

  /// Spelled-out numbers that would state a count or a span the model was not
  /// given. "One" is left out: "one thing" says nothing about the story.
  static const _numberWords = {
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'eleven',
    'twelve',
    'twenty',
    'thirty',
    'forty',
    'fifty',
    'sixty',
    'seventy',
    'eighty',
    'ninety',
    'hundred',
    'thousand',
    'million',
  };

  static Set<String> _tokens(Iterable<String> texts) => {
    for (final t in texts)
      for (final m in RegExp(
        r"[\p{L}\p{N}][\p{L}\p{N}'’-]*",
        unicode: true,
      ).allMatches(t))
        m.group(0)!.toLowerCase(),
  };

  /// Capitalised words that do not start a sentence, and any number, that appear in
  /// [text] but in nothing the model was given.
  static List<String> _newNames(String text, Set<String> known) {
    final out = <String>[];
    final words = RegExp(
      r"[\p{L}\p{N}][\p{L}\p{N}'’-]*",
      unicode: true,
    ).allMatches(text);
    for (final m in words) {
      final w = m.group(0)!;
      final lower = w.toLowerCase();
      if (known.contains(lower)) continue;
      if (RegExp(r'\d').hasMatch(w) || _numberWords.contains(lower)) {
        out.add(w);
        continue;
      }
      final capital = w[0] != w[0].toLowerCase();
      if (!capital || w == 'I' || w.startsWith("I'") || w.startsWith('I’')) {
        continue;
      }
      // A sentence's first word is capitalised anyway.
      final head = text.substring(0, m.start).trimRight();
      final startsSentence = head.isEmpty || RegExp(r'[.!?…]$').hasMatch(head);
      if (!startsSentence) out.add(w);
    }
    return out;
  }
}
