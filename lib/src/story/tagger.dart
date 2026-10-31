/// Part-of-speech tags and lemmas for story text, from word lists and context rules.
///
/// This is deliberately the least ambitious stage. It answers "what kind of word is
/// this" and nothing else; it never decides who did what. A statistical tagger
/// (UD-trained) can replace it behind the same [Tagger] interface; `pennToUpos`
/// maps its tags to this inventory.
library;

import 'entities.dart';
import 'labels.dart';
import 'lexicon.dart';

abstract class Tagger {
  /// Returns [sentences] with a tag and lemma on every token. Offsets are untouched.
  List<Sentence> tag(List<Sentence> sentences);
}

class RuleTagger implements Tagger {
  RuleTagger({EntityRegistry? registry})
    : _registry = registry ?? EntityRegistry(const []);

  final EntityRegistry _registry;
  static final _lex = StoryLexicon.instance;

  @override
  List<Sentence> tag(List<Sentence> sentences) => [
    for (final s in sentences) s.withTokens(_tagSentence(s.tokens)),
  ];

  static bool _isWord(String t) => RegExp(r"^[A-Za-z]").hasMatch(t);
  static bool _isCap(String t) => RegExp(r'^[A-Z]').hasMatch(t);

  List<Token> _tagSentence(List<Token> tokens) {
    final tags = List<Upos?>.filled(tokens.length, null);
    final lemmas = List<String?>.filled(tokens.length, null);

    String lowerAt(int i) =>
        i >= 0 && i < tokens.length ? tokens[i].text.toLowerCase() : '';

    // The next word that is not an adverb or negation: "had never seen" -> seen.
    int skipAdverbs(int from) {
      var j = from;
      while (j < tokens.length) {
        final w = lowerAt(j);
        if (w == 'not' ||
            w == "n't" ||
            w == 'n’t' ||
            w == 'never' ||
            (w.endsWith('ly') && w.length > 4) ||
            StoryLexicon.sentenceAdverbs.contains(w)) {
          j++;
        } else {
          break;
        }
      }
      return j;
    }

    bool participleAt(int j) =>
        j < tokens.length &&
        _lex
            .verbReadings(lowerAt(j))
            .any(
              (e) => e.form == VerbForm.participle || e.form == VerbForm.past,
            );
    bool baseAt(int j) =>
        j < tokens.length &&
        _lex.verbReadings(lowerAt(j)).any((e) => e.form == VerbForm.base);

    for (var i = 0; i < tokens.length; i++) {
      final text = tokens[i].text;
      final w = text.toLowerCase();
      final prev = i > 0 ? tags[i - 1] : null;
      final prevWord = lowerAt(i - 1);

      // --- punctuation, numbers, clitics -------------------------------------
      if (!RegExp(r'[A-Za-z0-9]').hasMatch(text)) {
        tags[i] = Upos.punct;
        continue;
      }
      if (RegExp(r'^\d').hasMatch(text)) {
        tags[i] = Upos.num;
        continue;
      }
      if (w == "n't" || w == 'n’t') {
        tags[i] = Upos.part;
        lemmas[i] = 'not';
        continue;
      }
      if (w.startsWith("'") || w.startsWith('’')) {
        final k = w.substring(1);
        if (k == 's') {
          tags[i] = prev == Upos.pron ? Upos.aux : Upos.part;
          lemmas[i] = prev == Upos.pron ? 'be' : "'s";
        } else {
          tags[i] = Upos.aux;
          lemmas[i] = switch (k) {
            'll' => 'will',
            'd' => 'would',
            've' => 'have',
            're' || 'm' => 'be',
            _ => k,
          };
        }
        continue;
      }

      // --- names -------------------------------------------------------------
      final named = _registry.isName(text);
      final weekday = StoryLexicon.weekdays.contains(w) && _isCap(text);
      if (named || weekday || (_isCap(text) && i > 0 && prev != Upos.punct)) {
        // A capital mid-sentence is a name, unless it is "I".
        if (w != 'i') {
          tags[i] = Upos.propn;
          lemmas[i] = text;
          continue;
        }
      }
      if (_isCap(text) &&
          i > 0 &&
          prev == Upos.punct &&
          !StoryLexicon.closedClass(w).isNotEmpty &&
          _lex.verbReadings(w).isEmpty &&
          !StoryLexicon.adjectives.contains(w) &&
          !_looksLikeCommonWord(w)) {
        // After an opening quote or comma a capitalised unknown word is a name.
        tags[i] = Upos.propn;
        lemmas[i] = text;
        continue;
      }

      // A capitalised word that starts a sentence and that no list knows is a name:
      // "Tilda hid the key." (A plural-looking word is more likely a common noun.)
      if (i == 0 &&
          _isCap(text) &&
          w != 'i' &&
          StoryLexicon.closedClass(w).isEmpty &&
          _lex.verbReadings(w).isEmpty &&
          !StoryLexicon.adjectives.contains(w) &&
          !StoryLexicon.ambiguousNouns.contains(w) &&
          !StoryLexicon.placeNouns.contains(w) &&
          !StoryLexicon.timeNouns.contains(w) &&
          !StoryLexicon.personNouns.contains(w) &&
          !(w.endsWith('s') && w.length > 3) &&
          i + 1 < tokens.length &&
          tokens[i + 1].text != ',') {
        tags[i] = Upos.propn;
        lemmas[i] = text;
        continue;
      }

      // --- closed-class words with context rules --------------------------------
      final next = i + 1 < tokens.length ? lowerAt(i + 1) : '';
      switch (w) {
        case 'that':
          if (const {
                'she',
                'he',
                'they',
                'i',
                'we',
                'it',
                'you',
                'the',
                'a',
                'an',
                'his',
                'her',
                'their',
                'its',
                'my',
                'our',
                'your',
                'there',
              }.contains(next) ||
              (i + 1 < tokens.length && _isCap(tokens[i + 1].text))) {
            tags[i] = Upos.sconj;
          } else if (i + 1 < tokens.length &&
              _isWord(tokens[i + 1].text) &&
              !StoryLexicon.closedClass(next).isNotEmpty &&
              !_lex.verbReadings(next).any((e) => e.form != VerbForm.base)) {
            tags[i] = Upos.det;
          } else {
            tags[i] = Upos.sconj;
          }
          lemmas[i] = 'that';
          continue;
        case 'her':
          final nextIsContent =
              i + 1 < tokens.length &&
              _isWord(tokens[i + 1].text) &&
              !StoryLexicon.prepositions.contains(next) &&
              !StoryLexicon.coordinators.contains(next) &&
              !StoryLexicon.subordinators.contains(next) &&
              !StoryLexicon.pronouns.contains(next) &&
              !StoryLexicon.determiners.contains(next) &&
              !StoryLexicon.beForms.contains(next) &&
              !StoryLexicon.haveForms.contains(next) &&
              !StoryLexicon.doForms.contains(next);
          tags[i] = nextIsContent ? Upos.det : Upos.pron;
          lemmas[i] = 'she';
          if (nextIsContent) lemmas[i] = 'her';
          continue;
        case 'to':
          final n = skipAdverbs(i + 1);
          if (n < tokens.length &&
              baseAt(n) &&
              !StoryLexicon.determiners.contains(lowerAt(n))) {
            final nw = lowerAt(n);
            final onlyVerb = !StoryLexicon.ambiguousNouns.contains(nw);
            final afterVerbOfWanting = prev == Upos.verb || i == 0;
            tags[i] = (onlyVerb || afterVerbOfWanting) ? Upos.part : Upos.adp;
          } else {
            tags[i] = Upos.adp;
          }
          lemmas[i] = 'to';
          continue;
        case 'before' || 'after' || 'until' || 'since' || 'as':
          tags[i] = StoryLexicon.subjectPronouns.contains(next)
              ? Upos.sconj
              : Upos.adp;
          if (w == 'as' && tags[i] == Upos.adp) tags[i] = Upos.sconj;
          lemmas[i] = w;
          continue;
        case 'had' || 'has' || 'have' || 'having':
          final n = skipAdverbs(i + 1);
          tags[i] =
              (n < tokens.length &&
                  (lowerAt(n) == 'been' || participleAt(n) && !baseAt(n)))
              ? Upos.aux
              : Upos.verb;
          lemmas[i] = 'have';
          continue;
        case 'did' || 'does' || 'do':
          final n = skipAdverbs(i + 1);
          final nextIsNp =
              i + 1 < tokens.length &&
              (_isCap(tokens[i + 1].text) ||
                  StoryLexicon.determiners.contains(next) ||
                  StoryLexicon.subjectPronouns.contains(next));
          tags[i] =
              ((n < tokens.length && baseAt(n)) ||
                  nextIsNp ||
                  n >= tokens.length)
              ? Upos.aux
              : Upos.verb;
          lemmas[i] = 'do';
          continue;
        case 'no':
          tags[i] = (i == 0 && next == ',') ? Upos.intj : Upos.det;
          lemmas[i] = 'no';
          continue;
        case 'so':
          tags[i] =
              (StoryLexicon.subjectPronouns.contains(next) ||
                  StoryLexicon.determiners.contains(next))
              ? Upos.cconj
              : Upos.adv;
          lemmas[i] = 'so';
          continue;
        case 'one':
          tags[i] =
              (i + 1 < tokens.length &&
                  _isWord(tokens[i + 1].text) &&
                  next != 'of')
              ? Upos.num
              : Upos.pron;
          lemmas[i] = 'one';
          continue;
        case 'well':
          tags[i] = Upos.adv;
          lemmas[i] = 'well';
          continue;
        case 'there':
          tags[i] = Upos.pron;
          lemmas[i] = 'there';
          continue;
        case 'up' || 'out' || 'down' || 'off' || 'back' || 'away':
          tags[i] =
              (i + 1 < tokens.length && StoryLexicon.determiners.contains(next))
              ? Upos.adp
              : Upos.adv;
          lemmas[i] = w;
          continue;
      }
      if (StoryLexicon.beForms.contains(w)) {
        tags[i] = Upos.aux;
        lemmas[i] = 'be';
        continue;
      }
      if (StoryLexicon.modalsPossible.contains(w) ||
          StoryLexicon.modalsCertain.contains(w)) {
        tags[i] = Upos.aux;
        lemmas[i] = w;
        continue;
      }
      if (w == 'who' || w == 'whom' || w == 'what' || w == 'which') {
        tags[i] =
            (w == 'what' || w == 'which') &&
                i + 1 < tokens.length &&
                _isWord(tokens[i + 1].text) &&
                !StoryLexicon.beForms.contains(next) &&
                !StoryLexicon.doForms.contains(next) &&
                !StoryLexicon.modalsPossible.contains(next)
            ? Upos.det
            : Upos.pron;
        lemmas[i] = w;
        continue;
      }
      if (StoryLexicon.pronouns.contains(w)) {
        tags[i] = Upos.pron;
        lemmas[i] = switch (w) {
          'him' => 'he',
          'them' => 'they',
          'me' => 'i',
          'us' => 'we',
          _ => w,
        };
        continue;
      }
      if (StoryLexicon.determiners.contains(w)) {
        tags[i] = Upos.det;
        lemmas[i] = w;
        continue;
      }
      if (StoryLexicon.coordinators.contains(w)) {
        tags[i] = Upos.cconj;
        lemmas[i] = w;
        continue;
      }
      if (StoryLexicon.subordinators.contains(w)) {
        tags[i] = Upos.sconj;
        lemmas[i] = w;
        continue;
      }
      if (StoryLexicon.interjections.contains(w) && w != 'yes') {
        tags[i] = Upos.intj;
        lemmas[i] = w;
        continue;
      }
      if (w == 'not') {
        tags[i] = Upos.part;
        lemmas[i] = 'not';
        continue;
      }
      if (StoryLexicon.numberWords.contains(w)) {
        tags[i] = Upos.num;
        lemmas[i] = w;
        continue;
      }
      if (StoryLexicon.prepositions.contains(w) &&
          !_lex.verbReadings(w).isNotEmpty) {
        tags[i] = Upos.adp;
        lemmas[i] = w;
        continue;
      }
      if (StoryLexicon.adverbs.contains(w)) {
        tags[i] = Upos.adv;
        lemmas[i] = w;
        continue;
      }

      // --- open-class words -------------------------------------------------------
      final readings = _lex.verbReadings(w);
      final isAdj = StoryLexicon.adjectives.contains(w);
      final nounish =
          StoryLexicon.ambiguousNouns.contains(w) ||
          readings.isEmpty ||
          readings.every((e) => e.form == VerbForm.thirdPerson);
      final afterDeterminer =
          prev == Upos.det ||
          prev == Upos.adj ||
          prev == Upos.num ||
          prev == Upos.adp;
      final afterAux =
          prev == Upos.aux ||
          (prev == Upos.part) ||
          (prev == Upos.adv &&
              i > 1 &&
              (tags[i - 2] == Upos.aux || tags[i - 2] == Upos.part));
      final afterSubject =
          prev == Upos.propn || prev == Upos.pron || prev == Upos.noun;
      final nextTok = i + 1 < tokens.length ? tokens[i + 1] : null;
      final nextWord = nextTok?.text.toLowerCase() ?? '';
      final nextIsNominal =
          nextTok != null &&
          _isWord(nextTok.text) &&
          !StoryLexicon.closedClass(nextWord).contains(Upos.adp) &&
          !StoryLexicon.coordinators.contains(nextWord) &&
          !StoryLexicon.subordinators.contains(nextWord) &&
          (StoryLexicon.adjectives.contains(nextWord) ||
              _lex.verbReadings(nextWord).isEmpty ||
              StoryLexicon.ambiguousNouns.contains(nextWord)) &&
          !StoryLexicon.beForms.contains(nextWord) &&
          !StoryLexicon.haveForms.contains(nextWord) &&
          !StoryLexicon.doForms.contains(nextWord) &&
          !StoryLexicon.pronouns.contains(nextWord) &&
          !StoryLexicon.determiners.contains(nextWord);

      if (readings.isNotEmpty) {
        VerbEntry? pick(bool Function(VerbEntry) f) {
          for (final e in readings) {
            if (f(e)) return e;
          }
          return null;
        }

        final participle = pick(
          (e) => e.form == VerbForm.participle || e.form == VerbForm.past,
        );
        final afterBe =
            prev == Upos.aux ||
            (prev == Upos.adv && i > 1 && tags[i - 2] == Upos.aux);
        final lastBe = StoryLexicon.beForms.contains(
          prev == Upos.adv && i > 1 ? lowerAt(i - 2) : prevWord,
        );
        // An adjective that is also a verb form is an adjective between a determiner
        // and a noun ("the broken lantern") or after "be" ("was broken"); anywhere
        // else ("opened", "open the door") the verb reading wins.
        final adjectiveHere =
            isAdj &&
            (prev == Upos.det ||
                prev == Upos.adj ||
                prev == Upos.num ||
                (afterBe &&
                    lastBe &&
                    participle != null &&
                    !baseOnly(readings)));
        final participleAdjective =
            participle != null &&
            prev == Upos.det &&
            nextIsNominal &&
            (w.endsWith('en') || w.endsWith('ed'));
        if (adjectiveHere || participleAdjective) {
          tags[i] = Upos.adj;
          lemmas[i] = w;
          continue;
        }
        if (afterAux) {
          final e =
              pick((e) => e.form == VerbForm.participle) ?? pick((e) => true)!;
          tags[i] = Upos.verb;
          lemmas[i] = e.lemma;
          continue;
        }
        if (StoryLexicon.ambiguousNouns.contains(w) &&
            afterDeterminer &&
            !isAdj) {
          tags[i] = Upos.noun;
          lemmas[i] = w;
          continue;
        }
        if (readings.every(
              (e) =>
                  e.form == VerbForm.thirdPerson || e.form == VerbForm.gerund,
            ) &&
            afterDeterminer) {
          // "the lights", "the morning": plural or gerund noun after a determiner.
          tags[i] = Upos.noun;
          lemmas[i] = _singular(w);
          continue;
        }
        final e =
            pick((e) => e.form == VerbForm.past) ??
            pick((e) => e.form == VerbForm.thirdPerson) ??
            pick((e) => e.form == VerbForm.participle) ??
            pick((e) => e.form == VerbForm.base) ??
            readings.first;
        if (StoryLexicon.ambiguousNouns.contains(w) &&
            !afterSubject &&
            !afterAux) {
          // Bare ambiguous word with no subject before it: a noun, unless a determiner
          // follows ("hide the key").
          final determinerFollows = StoryLexicon.determiners.contains(nextWord);
          if (!determinerFollows && prev != Upos.punct && i != 0) {
            tags[i] = Upos.noun;
            lemmas[i] = _singular(w);
            continue;
          }
        }
        tags[i] = Upos.verb;
        lemmas[i] = e.lemma;
        continue;
      }
      if (isAdj) {
        tags[i] = Upos.adj;
        lemmas[i] = w;
        continue;
      }
      if (w.endsWith('ly') && w.length > 4 && !afterDeterminer) {
        tags[i] = Upos.adv;
        lemmas[i] = w;
        continue;
      }
      if (w.endsWith('ed') && afterSubject && nounish && !afterDeterminer) {
        tags[i] = Upos.verb;
        lemmas[i] = _regularLemma(w);
        continue;
      }
      if (afterAux && nounish && w.endsWith('ed')) {
        tags[i] = Upos.verb;
        lemmas[i] = _regularLemma(w);
        continue;
      }
      tags[i] = Upos.noun;
      lemmas[i] = _singular(w);
    }

    return [
      for (var i = 0; i < tokens.length; i++)
        tokens[i].copyWith(
          pos: tags[i],
          lemma: lemmas[i] ?? tokens[i].text.toLowerCase(),
        ),
    ];
  }

  static bool baseOnly(List<VerbEntry> r) =>
      r.every((e) => e.form == VerbForm.base);

  static bool _looksLikeCommonWord(String w) => w.length <= 2;

  static String _regularLemma(String w) {
    if (w.endsWith('ied')) {
      // "tried" is try, "lied" is lie.
      final stem = w.substring(0, w.length - 3);
      return stem.length <= 1 ? '${stem}ie' : '${stem}y';
    }
    if (w.endsWith('ed')) {
      final stem = w.substring(0, w.length - 2);
      if (stem.length > 2 &&
          stem[stem.length - 1] == stem[stem.length - 2] &&
          !'aeiouls'.contains(stem[stem.length - 1])) {
        return stem.substring(0, stem.length - 1);
      }
      return stem;
    }
    return w;
  }

  /// A noun's singular: `letters` is `letter`, `keys` is `key`, `boxes` is `box`.
  static String _singular(String w) {
    final irr = StoryLexicon.irregularPlurals[w];
    if (irr != null) return irr;
    if (w.length < 4) return w;
    if (w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
    if (RegExp(r'(ss|us|is|ous)$').hasMatch(w)) return w;
    if (RegExp(r'(sses|xes|ches|shes|zes)$').hasMatch(w)) {
      return w.substring(0, w.length - 2);
    }
    if (w.endsWith('s')) return w.substring(0, w.length - 1);
    return w;
  }
}
