/// What words mean, as far as Companion can tell: the lexicon.
///
/// There is no model here. A character that seems to listen does so because it
/// noticed *which* word the author used and knows what kind of word it is: a feeling
/// and how strong, a relative, a kind of place, a kind of event. This file is that
/// knowledge, as data, in one place, so that making a character better at listening
/// means adding words and not changing code.
///
/// ## What it holds
///
/// * **Feelings**, in families (fear, anger, grief, shame, love, joy, hope, courage,
///   loneliness, envy, pride, relief, confusion), each word with how strong it is.
///   Families have opposites, so "afraid and brave" is known to be two things held
///   together and not one.
/// * **Negation and degree.** "Not afraid" is not a fear. "Terribly afraid" is
///   stronger than "afraid", and "a little afraid" is weaker.
/// * **Kin**, **kinds of place** and **kinds of event**: what a word like "mother" or
///   "funeral" or "harbour" is, for the characters' sake. The author's own names
///   (people, places, events in their project) come from their project, not from here.
///
/// Nothing here says anything on its own. It only recognises. What a character does
/// with what was recognised is `listening.dart`.
library;

/// A kind of feeling.
enum EmotionFamily {
  fear('fear'),
  anger('anger'),
  grief('grief'),
  shame('shame'),
  love('tenderness'),
  joy('joy'),
  hope('hope'),
  courage('courage'),
  loneliness('loneliness'),
  envy('envy'),
  pride('pride'),
  relief('relief'),
  confusion('confusion');

  const EmotionFamily(this.noun);

  /// The family as a noun, for a sentence that is about the feeling rather than the
  /// word the author used: "What set off the fear?"
  final String noun;

  /// The family at the other end, if there is one.
  EmotionFamily? get opposite => switch (this) {
    EmotionFamily.fear => EmotionFamily.courage,
    EmotionFamily.courage => EmotionFamily.fear,
    EmotionFamily.shame => EmotionFamily.pride,
    EmotionFamily.pride => EmotionFamily.shame,
    EmotionFamily.loneliness => EmotionFamily.love,
    EmotionFamily.love => EmotionFamily.loneliness,
    EmotionFamily.grief => EmotionFamily.joy,
    EmotionFamily.joy => EmotionFamily.grief,
    _ => null,
  };
}

/// How strong a feeling-word is.
enum Intensity { low, mid, high }

/// One feeling the author named.
class EmotionHit {
  const EmotionHit({
    required this.word,
    required this.family,
    required this.intensity,
    this.negated = false,
  });

  /// The word as the author wrote it, lower-cased.
  final String word;
  final EmotionFamily family;

  /// With "very", "so", "a little" and the like already applied.
  final Intensity intensity;

  /// "Not afraid": named, and denied.
  final bool negated;

  @override
  String toString() =>
      'EmotionHit($word, ${family.name}, ${intensity.name}${negated ? ', negated' : ''})';
}

/// A relative, a kind of place or a kind of event the author mentioned.
class KindHit {
  const KindHit(this.word, this.kind);

  final String word;
  final String kind;
}

class Lexicon {
  const Lexicon._();

  // ---------------------------------------------------------------- feelings

  /// Base words by family and strength. Inflections (-s, -ed, -ing) are added below.
  static const _bases = <EmotionFamily, Map<Intensity, List<String>>>{
    EmotionFamily.fear: {
      Intensity.low: [
        'nervous',
        'uneasy',
        'worried',
        'apprehensive',
        'wary',
        'anxious',
        'unsettled',
        'jumpy',
      ],
      Intensity.mid: [
        'afraid',
        'scared',
        'fear',
        'frightened',
        'dread',
        'alarmed',
        'fearful',
        'spooked',
        'threatened',
      ],
      Intensity.high: [
        'terrified',
        'terror',
        'panic',
        'horrified',
        'petrified',
        'paralysed',
        'paralyzed',
        'dread',
      ],
    },
    EmotionFamily.anger: {
      Intensity.low: ['annoyed', 'irritated', 'bitter', 'resentful'],
      Intensity.mid: [
        'angry',
        'anger',
        'mad',
        'furious',
        'resent',
        'enraged',
        'livid',
      ],
      Intensity.high: ['rage', 'raging', 'seething', 'wrath', 'hatred', 'hate'],
    },
    EmotionFamily.grief: {
      Intensity.low: ['sad', 'wistful', 'melancholy', 'sorrowful'],
      Intensity.mid: [
        'sadness',
        'sorrow',
        'grief',
        'grieving',
        'mourning',
        'hurt',
        'regret',
      ],
      Intensity.high: [
        'heartbroken',
        'devastated',
        'anguish',
        'despair',
        'crushed',
        'bereft',
        'inconsolable',
      ],
    },
    EmotionFamily.shame: {
      Intensity.low: ['embarrassed', 'awkward', 'sheepish', 'self-conscious'],
      Intensity.mid: [
        'ashamed',
        'shame',
        'guilty',
        'guilt',
        'remorse',
        'remorseful',
      ],
      Intensity.high: ['humiliated', 'mortified', 'disgraced', 'disgusted'],
    },
    EmotionFamily.love: {
      Intensity.low: ['fond'],
      Intensity.mid: [
        'love',
        'loved',
        'loving',
        'tender',
        'tenderness',
        'affection',
        'devoted',
        'cherish',
        'adore',
      ],
      Intensity.high: ['devotion', 'besotted', 'smitten', 'worship'],
    },
    EmotionFamily.joy: {
      Intensity.low: ['pleased', 'glad'],
      Intensity.mid: [
        'happy',
        'joy',
        'joyful',
        'delighted',
        'cheerful',
        'grateful',
        'thankful',
      ],
      Intensity.high: [
        'elated',
        'ecstatic',
        'overjoyed',
        'euphoric',
        'radiant',
        'thrilled',
      ],
    },
    EmotionFamily.hope: {
      Intensity.low: [],
      Intensity.mid: [
        'hopeful',
        'hope',
        'hoping',
        'optimistic',
        'expectant',
        'longing',
      ],
      Intensity.high: ['yearning', 'desperate', 'aching', 'craving'],
    },
    EmotionFamily.courage: {
      Intensity.low: ['resolute', 'unflinching'],
      Intensity.mid: [
        'brave',
        'bravery',
        'courage',
        'courageous',
        'bold',
        'determined',
        'defiant',
        'fearless',
      ],
      Intensity.high: ['heroic', 'valiant', 'undaunted', 'indomitable'],
    },
    EmotionFamily.loneliness: {
      Intensity.low: ['alone', 'isolated', 'withdrawn'],
      Intensity.mid: [
        'lonely',
        'loneliness',
        'abandoned',
        'forgotten',
        'unseen',
        'unwanted',
      ],
      Intensity.high: ['desolate', 'forsaken', 'outcast', 'friendless'],
    },
    EmotionFamily.envy: {
      Intensity.low: ['wistful', 'covetous'],
      Intensity.mid: ['jealous', 'jealousy', 'envy', 'envious', 'resentful'],
      Intensity.high: ['green-eyed', 'possessive'],
    },
    EmotionFamily.pride: {
      Intensity.low: ['satisfied', 'assured', 'confident'],
      Intensity.mid: ['proud', 'pride', 'dignified'],
      Intensity.high: ['triumphant', 'arrogant', 'imperious'],
    },
    EmotionFamily.relief: {
      Intensity.low: [],
      Intensity.mid: ['relieved', 'relief', 'comforted', 'reassured'],
      Intensity.high: ['liberated', 'unburdened', 'freed'],
    },
    EmotionFamily.confusion: {
      Intensity.low: ['hesitant', 'torn', 'doubtful'],
      Intensity.mid: [
        'confused',
        'confusion',
        'conflicted',
        'puzzled',
        'baffled',
      ],
      Intensity.high: ['bewildered', 'disoriented', 'adrift', 'overwhelmed'],
    },
  };

  /// Every form of every feeling-word, to its family and strength. Where one word is
  /// listed under two families (dread, resentful, wistful, consumed), the first wins.
  static final Map<String, (EmotionFamily, Intensity)> _emotions = () {
    final out = <String, (EmotionFamily, Intensity)>{};
    void add(String w, EmotionFamily f, Intensity i) =>
        out.putIfAbsent(w, () => (f, i));
    for (final fam in _bases.entries) {
      for (final level in fam.value.entries) {
        for (final base in level.value) {
          add(base, fam.key, level.key);
          for (final form in _inflect(base)) {
            add(form, fam.key, level.key);
          }
        }
      }
    }
    return out;
  }();

  static Iterable<String> _inflect(String w) sync* {
    if (w.contains('-')) return;
    if (w.endsWith('e')) {
      yield '${w}s';
      yield '${w}d';
      yield '${w.substring(0, w.length - 1)}ing';
    } else if (w.endsWith('y') && w.length > 3) {
      final stem = w.substring(0, w.length - 1);
      yield '${stem}ies';
      yield '${stem}ied';
    } else {
      yield '${w}s';
      yield '${w}ed';
      yield '${w}ing';
    }
  }

  /// Words that deny what follows.
  static const _negators = {
    'not',
    "n't",
    'never',
    'no',
    'without',
    'hardly',
    'neither',
    'nor',
    'wasnt',
    'isnt',
    'arent',
    'werent',
    'dont',
    'doesnt',
    'didnt',
    'cant',
    'couldnt',
    'wont',
    'wouldnt',
    'barely',
  };

  static const _raisers = {
    'very',
    'so',
    'terribly',
    'utterly',
    'completely',
    'deeply',
    'truly',
    'really',
    'extremely',
    'incredibly',
    'totally',
    'absolutely',
    'wholly',
  };

  static const _lowerers = {
    'slightly',
    'somewhat',
    'faintly',
    'mildly',
    'bit',
    'little',
    'vaguely',
    'rather',
    'kinda',
    'sorta',
    'almost',
  };

  /// How many words back a negator or an intensifier still reaches.
  static const _reach = 3;

  /// Where a denial or an intensifier stops reaching: punctuation, and the words that
  /// turn a sentence ("not afraid, but brave").
  static final _clauseBreak = RegExp(
    r'[.,;:!?()\u2014|]|\bbut\b|\byet\b|\balthough\b|\bthough\b',
    caseSensitive: false,
  );

  static List<String> _words(String clause) => [
    for (final m in RegExp(r"[A-Za-z][A-Za-z'-]*").allMatches(clause))
      m
          .group(0)!
          .toLowerCase()
          .replaceAll(RegExp(r"n't$"), 'nt')
          .replaceAll("'", ''),
  ];

  static List<String> _tokens(String text) => _words(text);

  /// The feelings in [text], in the order they appear, with what the words around
  /// them did to them.
  static List<EmotionHit> emotions(String text) {
    final hits = <EmotionHit>[];
    for (final clause in text.split(_clauseBreak)) {
      final words = _words(clause);
      for (var i = 0; i < words.length; i++) {
        final entry = _emotions[words[i]];
        if (entry == null) continue;
        var negated = false;
        var strength = entry.$2.index;
        for (var j = (i - _reach).clamp(0, i); j < i; j++) {
          if (_negators.contains(words[j])) negated = true;
          if (_raisers.contains(words[j])) strength += 1;
          if (_lowerers.contains(words[j])) strength -= 1;
        }
        hits.add(
          EmotionHit(
            word: words[i],
            family: entry.$1,
            intensity: Intensity.values[strength.clamp(0, 2)],
            negated: negated,
          ),
        );
      }
    }
    return hits;
  }

  /// The surface words of the feelings that were *felt*: named and not denied.
  static Set<String> feltWords(String text) => {
    for (final h in emotions(text))
      if (!h.negated) h.word,
  };

  /// Two feelings at once that pull against each other, if the author named any:
  /// "afraid, and brave".
  static (EmotionHit, EmotionHit)? contrast(List<EmotionHit> hits) {
    final felt = [
      for (final h in hits)
        if (!h.negated) h,
    ];
    for (final a in felt) {
      final opposite = a.family.opposite;
      if (opposite == null) continue;
      for (final b in felt) {
        if (b.family == opposite) return (a, b);
      }
    }
    return null;
  }

  // ----------------------------------------------------------- kin and kinds

  static const _kin = {
    'mother',
    'mum',
    'mom',
    'father',
    'dad',
    'brother',
    'sister',
    'son',
    'daughter',
    'wife',
    'husband',
    'grandmother',
    'grandfather',
    'gran',
    'granddad',
    'aunt',
    'uncle',
    'cousin',
    'parents',
    'family',
    'child',
    'children',
    'baby',
    'twin',
    'orphan',
  };

  static const _placeKinds = {
    'water',
    'sea',
    'ocean',
    'river',
    'lake',
    'harbour',
    'harbor',
    'dock',
    'shore',
    'beach',
    'house',
    'home',
    'room',
    'kitchen',
    'attic',
    'cellar',
    'road',
    'street',
    'bridge',
    'forest',
    'woods',
    'field',
    'hill',
    'mountain',
    'school',
    'church',
    'tavern',
    'inn',
    'market',
    'prison',
    'tower',
    'castle',
    'village',
    'town',
    'city',
    'island',
    'cave',
    'garden',
    'marsh',
    'desert',
  };

  static const _eventKinds = {
    'funeral',
    'wedding',
    'fight',
    'war',
    'battle',
    'wreck',
    'fire',
    'storm',
    'flood',
    'birth',
    'death',
    'accident',
    'betrayal',
    'argument',
    'escape',
    'journey',
    'return',
    'leaving',
    'trial',
    'secret',
    'lie',
    'promise',
    'illness',
    'disaster',
    'robbery',
    'murder',
  };

  /// Relatives, kinds of place and kinds of event named in [text], in order.
  static List<KindHit> kinds(String text) {
    final out = <KindHit>[];
    final seen = <String>{};
    for (final w in _tokens(text)) {
      final kind = _kin.contains(w)
          ? 'kin'
          : _placeKinds.contains(w)
          ? 'place'
          : _eventKinds.contains(w)
          ? 'event'
          : null;
      if (kind != null && seen.add(w)) out.add(KindHit(w, kind));
    }
    return out;
  }

  /// How many feeling-words, kin and kind-words the lexicon holds, for a report.
  static int get size =>
      _emotions.length + _kin.length + _placeKinds.length + _eventKinds.length;
}
