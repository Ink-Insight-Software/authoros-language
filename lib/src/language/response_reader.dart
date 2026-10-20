/// Reading what the author wrote (plan 2.9).
///
/// Authors write the way people talk: a word, a paragraph, "hm, maybe", "actually
/// no", a question back. [AuthorResponseReader] turns that into an
/// [AuthorResponseAnalysis] (the raw text, kept, plus what it was doing and what
/// it named) without asking the author to fill in a form.
///
/// [RuleBasedResponseReader] is the first reader. It works from phrase lists and
/// patterns, and where it is unsure it errs towards *not* claiming a fact:
///
/// * a hedged answer ("maybe she…", "what if…", a list of options) is marked as
///   having several possibilities, which the engine never treats as settled;
/// * "I don't know" on its own is uncertainty, but "I don't know, she just seems
///   sad" is an answer;
/// * "stop" counts only where it is an instruction, not where it is a word in the
///   author's story ("she couldn't stop crying").
library;

import '../conversation/author_response.dart';
import 'lexicon.dart';

/// Names the project already holds, so a mention can be recognised as one.
class ReaderContext {
  const ReaderContext({
    this.people = const {},
    this.places = const {},
    this.events = const {},
  });

  final Set<String> people;
  final Set<String> places;
  final Set<String> events;
}

abstract interface class AuthorResponseReader {
  AuthorResponseAnalysis read(
    String text, {
    ReaderContext context = const ReaderContext(),
  });
}

class RuleBasedResponseReader implements AuthorResponseReader {
  const RuleBasedResponseReader();

  static String _normalise(String s) => s
      .replaceAll(RegExp('[‘’]'), "'")
      .replaceAll(RegExp('[“”]'), '"')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static RegExp _phrases(Iterable<String> phrases) =>
      RegExp('\\b(?:${phrases.map(RegExp.escape).join('|')})\\b');

  static final _uncertain = _phrases([
    "i don't know",
    'i do not know',
    "i dont know",
    'idk',
    'dunno',
    'not sure',
    'not certain',
    'no idea',
    'no clue',
    'unsure',
    "i can't say",
    "i couldn't say",
    'hard to say',
    "don't really know",
    'maybe',
    'perhaps',
    'i guess',
  ]);

  static final _hedge = _phrases([
    'maybe',
    'perhaps',
    'might',
    'i guess',
    'what if',
    'thinking out loud',
    'brainstorm',
    'not sure yet',
    'could be',
  ]);

  static final _several = RegExp(
    r'\b(or maybe|or perhaps|or it could|or she might|or he might|or they might|'
    r'either\b.*\bor\b|one possibility|another possibility|alternatively|'
    r'on the other hand|what if|thinking out loud|brainstorm)\b'
    r'|(^|\s)1[.)]\s.*\s2[.)]\s',
  );

  static final _correction = RegExp(
    r"(^|[.!?]\s+)(no[, ]+)?actually\b|\b(i meant|scratch that|correction|"
    r"let me correct|not quite|no wait|wait, no|i misspoke|"
    r"that's wrong|that is wrong|that's not right|that isn't right|"
    r"that's incorrect|that is incorrect|you've got it wrong|you have it wrong)\b",
  );

  static final _disagreement = RegExp(
    r"\b(i disagree|i don't agree|i do not agree|i don't think so|"
    r"you're wrong|you are wrong|that's not true|that is not true|no way|"
    r"that's not her|that's not him|that's not them|that doesn't sound like|"
    r"i don't buy|not what (she|he|they|i)'d)\b",
  );

  static final _topicChange = _phrases([
    "let's talk about",
    'lets talk about',
    'let us talk about',
    'can we talk about',
    'could we talk about',
    'change the subject',
    'change subject',
    'another topic',
    'different topic',
    'different question',
    'move on',
    'switch to',
    'switch topics',
    'talk about something else',
    'ask something else',
    'ask me something else',
    'try something else',
    'try another approach',
    'try a different approach',
    'another approach',
    'different approach',
    'next topic',
    'new topic',
  ]);

  static final _stop = RegExp(
    r"(^|[.!?]\s+)(please\s+)?stop(\s*$|[.!,]|\s+(asking|this|it|please|talking|now|there))"
    r"|,\s*(please\s+)?stop\s*[.!]"
    r"|(^|[.!?]\s+)(enough|pause|hold on)\b"
    r"|\b(that's enough|that is enough|i'm done|i am done|no more questions|"
    r"drop it|let's stop|lets stop|can we stop|let's end|end this|"
    r"(don't|do not|can't|cannot) want to talk about|(can't|cannot) talk about (this|that|it)|"
    r"i want to stop|not now|let's pause|need a break|take a break)\b",
  );

  static final _skip = RegExp(
    r"^(skip|pass|next)\b|\b(skip this|skip it|next question|rather not say|"
    r"rather not answer|don't want to answer|do not want to answer|no comment|"
    r"i'll pass|i will pass|not going to answer|prefer not to say|"
    r"prefer not to answer)\b",
  );

  static final _questionOpen = RegExp(
    r'^(what|why|how|do|would|did|are|were|can|could|will|who|where|when|and)\b.*\byou\b',
  );

  static const _filler = {
    'well',
    'um',
    'uh',
    'hm',
    'hmm',
    'oh',
    'ok',
    'okay',
    'so',
    'and',
    'but',
    'i',
    'it',
    'is',
    'a',
    'the',
    'just',
    'really',
    'honestly',
    'yeah',
    'no',
    'yes',
    'to',
    'of',
    'about',
    'that',
    'this',
    'we',
    'let',
    'us',
    'please',
    'can',
    'could',
    'me',
    'you',
    'my',
    'now',
    'not',
    'sure',
    'know',
  };

  static const _end =
      r"(?=[.,;:!?]|\s+(?:and|but|because|since|when|after|so|until|which|that)\b|$)";

  static final _fearPatterns = [
    RegExp(r'\b(?:afraid|scared|terrified|frightened)\s+of\s+(.+?)' + _end),
    RegExp(r'\b(?:fear|phobia|dread)\s+of\s+(.+?)' + _end),
    RegExp(r'\bfears\s+(?!of\b)(.+?)' + _end),
    RegExp(r'\bdreads\s+(.+?)' + _end),
  ];

  static final _motivationPatterns = [
    RegExp(
      r'\b(?:wants?|wanted|needs?|needed|hopes?|hoped|longs?|determined)\s+to\s+(.+?)' +
          _end,
    ),
    RegExp(r'\b(?:driven|motivated)\s+by\s+(.+?)' + _end),
    RegExp(r'\bin order to\s+(.+?)' + _end),
    RegExp(r'\b(?:is|was)\s+trying\s+to\s+(.+?)' + _end),
  ];

  static final _valuePatterns = [
    RegExp(r'\bbelieves?\s+in\s+(.+?)' + _end),
    RegExp(r'\bvalues?\s+(.+?)' + _end),
    RegExp(r'\bcares?\s+(?:deeply\s+)?(?:about|for)\s+(.+?)' + _end),
    RegExp(r'\b(?:loyal|devoted|committed)\s+to\s+(.+?)' + _end),
  ];

  @override
  AuthorResponseAnalysis read(
    String text, {
    ReaderContext context = const ReaderContext(),
  }) {
    final norm = _normalise(text);
    if (norm.isEmpty) {
      return AuthorResponseAnalysis(rawText: text, intents: const {});
    }

    final wantsStop = _stop.hasMatch(norm);
    final skips = _skip.hasMatch(norm);
    final changes = _topicChange.hasMatch(norm);
    final uncertainHit = _uncertain.hasMatch(norm);

    // What is left once the instructions and the shrugs are taken out.
    var rest = norm;
    for (final r in [_uncertain, _topicChange, _stop, _skip]) {
      rest = rest.replaceAll(r, ' ');
    }
    final content = rest
        .split(RegExp(r"[^a-z0-9']+"))
        .where((w) => w.isNotEmpty && !_filler.contains(w))
        .length;
    final hasContent = content >= 2;

    final intents = <ResponseIntent>{};
    if (wantsStop) intents.add(ResponseIntent.stop);
    if (skips) intents.add(ResponseIntent.skip);
    if (changes) intents.add(ResponseIntent.topicChange);
    if (uncertainHit && !hasContent) intents.add(ResponseIntent.uncertain);
    if (_correction.hasMatch(norm)) intents.add(ResponseIntent.correction);
    if (_disagreement.hasMatch(norm)) intents.add(ResponseIntent.disagreement);
    if (text.contains('?') || _questionOpen.hasMatch(norm)) {
      intents.add(ResponseIntent.questionBack);
    }
    // Tentative answers are never settled: mark them as open possibilities.
    if (_several.hasMatch(norm) || (hasContent && _hedge.hasMatch(norm))) {
      intents.add(ResponseIntent.multiplePossibilities);
    }
    if (hasContent && !wantsStop && !skips) intents.add(ResponseIntent.answer);

    return AuthorResponseAnalysis(
      rawText: text,
      intents: intents,
      terms: _terms(text, norm, context),
    );
  }

  ResponseTerms _terms(String raw, String norm, ReaderContext c) {
    Set<String> known(Set<String> names) => {
      for (final n in names)
        if (n.trim().length > 1 &&
            RegExp(
              '\\b${RegExp.escape(n.trim())}\\b',
              caseSensitive: false,
            ).hasMatch(raw))
          n.trim(),
    };

    Set<String> capture(List<RegExp> patterns) {
      final found = <String>{};
      for (final p in patterns) {
        for (final m in p.allMatches(norm)) {
          var t = m.group(1)!.trim();
          t = t.replaceFirst(
            RegExp(r'^(the|a|an|her|his|their|my|being|having)\s+'),
            '',
          );
          final words = t.split(' ');
          if (words.length > 5) t = words.take(5).join(' ');
          if (t.length >= 3) found.add(t);
        }
      }
      return found;
    }

    // Felt, not denied: "not afraid" names a fear and says there is none.
    final emotions = Lexicon.feltWords(raw);
    return ResponseTerms(
      people: known(c.people),
      places: known(c.places),
      events: known(c.events),
      emotions: emotions,
      motivations: capture(_motivationPatterns),
      values: capture(_valuePatterns),
      fears: capture(_fearPatterns),
    );
  }
}
