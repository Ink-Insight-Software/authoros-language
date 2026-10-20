/// A character noticing what was said (and saying so).
///
/// Before this, a character acknowledged the author about four times in ten, with
/// one of three lines that said nothing ("I see", "Noted", "Understood"). Now every
/// real answer is acknowledged, and the acknowledgement is *about* the answer: it
/// picks up the feeling the author named, the person, the place, the event, the
/// thing wanted or feared, and says it back. It is the lexicon's recognition
/// (`lexicon.dart`) plus a small grammar for what a character may say about each
/// kind of word, said in the character's tone.
///
/// ## What a character may say here
///
/// Only three kinds of thing:
///
/// * **The author's own words**, quoted: the feeling, the name, the thing wanted.
/// * **What the author's project says**, as being what they *wrote*: "You've put Tom
///   close to me", "You wrote that it is…". Never as the character's own claim.
/// * **A stock line**, from the banks below: a reaction, a reflection on a kind of
///   feeling, a remark that something has come up before. These assert nothing about
///   the story.
///
/// So listening cannot put a fact into the character's mouth. Every stock line is in
/// [Listening.phrases], so a reviewer can read all of what a character may add.
library;

import 'package:authoros_core/procedural/generation_seed.dart';

import '../conversation/author_response.dart';
import '../voice/voice_profile.dart';
import 'lexicon.dart';
import 'manner_banks.dart';
import 'manner_shared.dart';

/// How a character's voice leans, for choosing among stock lines.
enum ListenTone {
  soft,
  neutral,
  sharp,
  sardonic,
  dry,
  blunt,
  formal,
  timid,
  quiet,
  playful,
  stoic;

  /// Warm, gentle and earnest share a bank; every other tone has its own in
  /// [MannerBanks].
  static ListenTone of(VoiceTone t) => switch (t) {
    VoiceTone.warm || VoiceTone.gentle || VoiceTone.earnest => soft,
    VoiceTone.neutral => neutral,
    VoiceTone.dry => dry,
    VoiceTone.sardonic => sardonic,
    VoiceTone.blunt => blunt,
    VoiceTone.formal => formal,
    VoiceTone.timid => timid,
    VoiceTone.quiet => quiet,
    VoiceTone.playful => playful,
    VoiceTone.stoic => stoic,
  };

  /// The older three-way bucket this tone falls back on when it has no bank.
  ListenTone get base => switch (this) {
    soft || neutral || sharp => this,
    _ => sharp,
  };
}

/// What the author said, read for listening.
class Heard {
  const Heard({
    required this.text,
    required this.words,
    this.feelings = const [],
    this.people = const {},
    this.places = const {},
    this.events = const {},
    this.kinds = const [],
    this.wants = const {},
    this.fears = const {},
    this.values = const {},
    this.engaged = false,
    this.uncertain = false,
    this.correction = false,
    this.disagreement = false,
    this.several = false,
    this.asksBack = false,
  });

  factory Heard.from(AuthorResponseAnalysis a) => Heard(
    text: a.rawText.trim(),
    words: a.wordCount,
    feelings: Lexicon.emotions(a.rawText),
    people: a.terms.people,
    places: a.terms.places,
    events: a.terms.events,
    kinds: Lexicon.kinds(a.rawText),
    wants: a.terms.motivations,
    fears: a.terms.fears,
    values: a.terms.values,
    engaged: a.isEngaged,
    uncertain: a.isUncertain,
    correction: a.isCorrection,
    disagreement: a.isDisagreement,
    several: a.hasSeveralPossibilities,
    asksBack: a.asksBack,
  );

  final String text;
  final int words;
  final List<EmotionHit> feelings;
  final Set<String> people;
  final Set<String> places;
  final Set<String> events;
  final List<KindHit> kinds;
  final Set<String> wants;
  final Set<String> fears;
  final Set<String> values;
  final bool engaged;
  final bool uncertain;
  final bool correction;
  final bool disagreement;
  final bool several;
  final bool asksBack;

  /// Feelings that were felt, not denied.
  List<EmotionHit> get felt => [
    for (final f in feelings)
      if (!f.negated) f,
  ];

  /// Feelings that were named and denied.
  List<EmotionHit> get denied => [
    for (final f in feelings)
      if (f.negated) f,
  ];

  /// The feeling the author gave the most weight, or null.
  EmotionHit? get strongest {
    EmotionHit? best;
    for (final f in felt) {
      if (best == null || f.intensity.index > best.intensity.index) best = f;
    }
    return best;
  }

  /// Something that carries weight: a strong feeling, two at once, a long answer.
  bool get weighty =>
      felt.any((f) => f.intensity == Intensity.high) ||
      Lexicon.contrast(feelings) != null ||
      felt.length >= 2 ||
      words >= 25;

  /// The first name of a person, for speaking.
  static String first(String name) => name.split(' ').first;
}

/// What the project says about the people and places the author may mention, as
/// things the author *wrote*.
class ListenCues {
  const ListenCues({this.links = const {}, this.placeNotes = const {}});

  /// For the character speaking: other characters' full names to how the project
  /// connects them (`confirmed`, `suspected`, `tension`, `unknown`).
  final Map<String, String> links;

  /// Place names to a line the author wrote about the place.
  final Map<String, String> placeNotes;
}

/// What a character says to show it heard.
class Acknowledgement {
  const Acknowledgement(this.lines, this.fragments);

  static const none = Acknowledgement([], []);

  final List<String> lines;

  /// Phrase ids used, so the same wording is not reached for again soon.
  final List<String> fragments;

  bool get isEmpty => lines.isEmpty;
}

class Listening {
  const Listening._();

  // ---------------------------------------------------------------- the banks

  static const _felt = <ListenTone, Map<Intensity, List<String>>>{
    ListenTone.soft: {
      Intensity.high: [
        '{W}. I can hear how much that weighs.',
        "{W}. That's a heavy word.",
      ],
      Intensity.mid: ['{W}. Yes.', "{W}. I'm listening."],
      Intensity.low: ['{W}, but only a little. All right.', '{W}, quietly.'],
    },
    ListenTone.neutral: {
      Intensity.high: [
        '{W}. That is a strong word.',
        '{W}. Not a small thing.',
      ],
      Intensity.mid: ['{W}. I see.', '{W}. Noted.'],
      Intensity.low: ['{W}, a little.', '{W}. Mildly, then.'],
    },
    ListenTone.sharp: {
      Intensity.high: ["{W}. That's not nothing.", '{W}. Not a small word.'],
      Intensity.mid: ['{W}. Right.', '{W}. Hm.'],
      Intensity.low: ['{W}. A little. Hm.', '{W}. Barely, then.'],
    },
  };

  static const _several = <ListenTone, List<String>>{
    ListenTone.soft: ["That's a lot at once.", 'Both, then.'],
    ListenTone.neutral: ['Both.', 'More than one thing at once.'],
    ListenTone.sharp: ['Naturally.', 'Of course it is more than one.'],
  };

  static const _contrast = <ListenTone, List<String>>{
    ListenTone.soft: [
      "That's a lot to hold.",
      'Both at once. That takes something.',
    ],
    ListenTone.neutral: ['Both can be true.', 'Held together.'],
    ListenTone.sharp: ["Of course it's both.", 'Naturally. Never one thing.'],
  };

  static const _denied = <ListenTone, List<String>>{
    ListenTone.soft: ['Not {W}. All right.', 'Not {W}. I hear that.'],
    ListenTone.neutral: ['Not {W}. Noted.', 'Not {W}. I see.'],
    ListenTone.sharp: ['Not {W}. If you say so.', 'Not {W}. Hm.'],
  };

  static const _person = <ListenTone, List<String>>{
    ListenTone.soft: ['{N}. Yes.', 'Ah, {N}.'],
    ListenTone.neutral: ['{N}. I see.', 'So {N} is part of this.'],
    ListenTone.sharp: ['{N}. Naturally.', '{N}. Of course.'],
  };

  static const _link = <String, String>{
    'confirmed': "You've put {N} close to me.",
    'suspected': "You've hinted there's something between {N} and me.",
    'tension': "You've written some friction between {N} and me.",
    'unknown': "You haven't said what {N} and I are to each other.",
  };

  static const _event = <ListenTone, List<String>>{
    ListenTone.soft: ['{E}. Yes.', '{E}. I understand.'],
    ListenTone.neutral: ['{E}. I see.', '{E}. Noted.'],
    ListenTone.sharp: ['{E}. There it is.', '{E}. Of course.'],
  };

  static const _place = <ListenTone, List<String>>{
    ListenTone.soft: ['{P}. Go on.', '{P}. Tell me more.'],
    ListenTone.neutral: ['{P}. Right.', '{P}. Go on.'],
    ListenTone.sharp: ['{P}. Hm.', '{P}. And?'],
  };

  static const _placeNote = 'You wrote that it is "{note}".';

  static const _kind = <ListenTone, List<String>>{
    ListenTone.soft: ['{K}. Say more about that.', '{K}. Yes.'],
    ListenTone.neutral: ['{K}. Go on.', '{K}. I see.'],
    ListenTone.sharp: ['{K}. And?', '{K}. Hm.'],
  };

  static const _kin = <ListenTone, List<String>>{
    ListenTone.soft: ['{K}. Family, then.', '{K}. That matters.'],
    ListenTone.neutral: ['{K}. I see.', '{K}. Family.'],
    ListenTone.sharp: ['{K}. Of course.', '{K}. Family. Naturally.'],
  };

  static const _fear = 'Afraid of {x}.';
  static const _want = 'Wanting to {x}.';
  static const _value = '{X}. That matters, then.';

  static const _correction = <ListenTone, List<String>>{
    ListenTone.soft: ['Then I had it wrong. Thank you.'],
    ListenTone.neutral: ['Then I had it wrong.'],
    ListenTone.sharp: ["Fine. I'll take the correction."],
  };

  static const _disagreement = <ListenTone, List<String>>{
    ListenTone.soft: ['You see it differently. Tell me how.'],
    ListenTone.neutral: ['You disagree. Say more.'],
    ListenTone.sharp: ['So you disagree. Go on.'],
  };

  static const _possibilities = <ListenTone, List<String>>{
    ListenTone.soft: [
      'More than one way it could go. Good to have them all out.',
    ],
    ListenTone.neutral: ['Several possibilities. None chosen yet.'],
    ListenTone.sharp: ['Several options. Pick one eventually.'],
  };

  static const _unsure = <ListenTone, List<String>>{
    ListenTone.soft: ["That's all right. We can come at it another way."],
    ListenTone.neutral: ['Fair enough. Another way in, then.'],
    ListenTone.sharp: ["Fine. We'll try another door."],
  };

  static const _echoTag = <ListenTone, List<String>>{
    ListenTone.soft: ['Mm.', 'Yes.'],
    ListenTone.neutral: ['I see.', 'Right.'],
    ListenTone.sharp: ['Right.', 'Hm.'],
  };

  /// What a character may say about a kind of feeling, said once it has been heard.
  static const _reflections = <EmotionFamily, List<String>>{
    EmotionFamily.fear: [
      'Fear usually points at something.',
      'Fear is easier to see once it has a shape.',
    ],
    EmotionFamily.anger: [
      'Anger is rarely about only one thing.',
      'Anger usually has something softer under it.',
    ],
    EmotionFamily.grief: [
      'Grief keeps its own hours.',
      'Grief is what love does with nowhere to go.',
    ],
    EmotionFamily.shame: [
      'Shame hides well.',
      'Shame makes people quieter than they mean to be.',
    ],
    EmotionFamily.love: [
      'That kind of care is hard to say out loud.',
      'Tenderness is easy to feel and hard to show.',
    ],
    EmotionFamily.joy: [
      "It's good to hear something light.",
      'Joy is easier to miss than pain.',
    ],
    EmotionFamily.hope: [
      'Hope is stubborn.',
      'Hope asks more of a person than giving up does.',
    ],
    EmotionFamily.courage: [
      'Courage is easier to name than to do.',
      'Courage tends to look smaller from the inside.',
    ],
    EmotionFamily.loneliness: [
      "Being alone and being lonely aren't the same thing.",
      'Loneliness gets louder at night.',
    ],
    EmotionFamily.envy: [
      'Envy is usually something else wearing a mask.',
      'Envy points at what someone wants.',
    ],
    EmotionFamily.pride: ['Pride has a cost.', 'Pride holds a lot up.'],
    EmotionFamily.relief: [
      'Relief shows what was being held.',
      'Relief often arrives with a little grief.',
    ],
    EmotionFamily.confusion: [
      'Not knowing is its own weight.',
      'Confusion often means two true things are pulling.',
    ],
  };

  static const _contrastReflections = [
    'Both can be true.',
    'Holding both is harder than choosing.',
  ];

  /// Lines the grammar composes around the author's words, listed as templates so
  /// the audit sees them.
  static const _composed = [
    '{A} and {B}, at once.',
    '{A} and {B}.',
    '{T}. Mm.',
    '{T}. Yes.',
    '{T}. I see.',
    '{T}. Right.',
    '{T}. Hm.',
  ];

  static const _back = '{W} again. You said that earlier too.';
  static const _backCount = "That's the {O} time {W} has come up.";

  /// Every stock line this can say, for auditing. Slots are written `{like this}`.
  static Set<String> get phrases => {
    for (final tone in _felt.values)
      for (final pool in tone.values) ...pool,
    for (final bank in [
      _several,
      _contrast,
      _denied,
      _person,
      _event,
      _place,
      _kind,
      _kin,
      _correction,
      _disagreement,
      _possibilities,
      _unsure,
      _echoTag,
    ])
      for (final pool in bank.values) ...pool,
    ...MannerBanks.phrases,
    ...MannerShared.phrases,
    ..._link.values,
    _placeNote,
    _fear,
    _want,
    _value,
    for (final pool in _reflections.values) ...pool,
    ..._contrastReflections,
    ..._composed,
    _back,
    _backCount,
  };

  static final List<RegExp> _patterns = [
    for (final p in phrases)
      RegExp(
        '^${p.splitMapJoin(RegExp(r'\{\w+\}'), onMatch: (_) => '\u0000', onNonMatch: RegExp.escape).replaceAll('\u0000', '(.+?)')}\$',
      ),
  ];

  /// Whether [line] is one of this module's stock lines, with the author's words or
  /// the project's in the slots. For auditing what a character may say.
  static bool isStock(String line) => _patterns.any((p) => p.hasMatch(line));

  // ------------------------------------------------------------------- helpers

  /// The lines for [tone]: its own bank if it has one, else the older three-way
  /// bucket it falls back on.
  static List<String> _pool(
    Map<ListenTone, List<String>> bank,
    ListenTone tone,
    List<String> Function(ListenBank) own,
  ) {
    final manner = MannerBanks.listening(tone);
    return manner != null ? own(manner) : bank[tone.base]!;
  }

  static List<String> _feltPool(ListenTone tone, Intensity i) {
    final manner = MannerBanks.listening(tone);
    if (manner == null) return _felt[tone.base]![i]!;
    return switch (i) {
      Intensity.high => manner.feltHigh,
      Intensity.mid => manner.feltMid,
      Intensity.low => manner.feltLow,
    };
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _fill(String template, Map<String, String> slots) =>
      template.replaceAllMapped(
        RegExp(r'\{(\w+)\}'),
        (m) => slots[m.group(1)!] ?? m.group(0)!,
      );

  /// The last few words of what the author said, to say back when nothing in it was
  /// recognised. Their own words.
  static String? tail(String text) {
    final clauses = text
        .split(RegExp(r'[.,;:!?]+|\s+(?:and|but|because)\s+'))
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (clauses.isEmpty) return null;
    final words = clauses.last.split(RegExp(r'\s+'));
    if (words.length < 2) return null;
    final cut = words.length > 6 ? words.sublist(words.length - 6) : words;
    return _cap(cut.join(' '));
  }

  static String _ordinal(int n) => switch (n) {
    2 => 'second',
    3 => 'third',
    4 => 'fourth',
    5 => 'fifth',
    6 => 'sixth',
    7 => 'seventh',
    8 => 'eighth',
    9 => 'ninth',
    10 => 'tenth',
    _ => '${n}th',
  };

  // ------------------------------------------------------------ acknowledging

  /// What to say to show [h] was heard. Empty when nothing was said worth
  /// acknowledging (a pass, a stop). A terse character says the least: one line.
  static Acknowledgement acknowledge(
    Heard h, {
    required ListenTone tone,
    required GenerationSeed seed,
    required int turn,
    List<String> recent = const [],
    ListenCues cues = const ListenCues(),
    bool terse = false,
  }) {
    final used = <String>[];
    String pick(String id, List<String> pool) {
      final fresh = [
        for (var i = 0; i < pool.length; i++)
          if (!recent.contains('$id.$i')) i,
      ];
      final from = fresh.isEmpty
          ? [for (var i = 0; i < pool.length; i++) i]
          : fresh;
      final roll = seed.derive('listen/$id').unitAt(turn, pool.length);
      final i = from[(roll * from.length).floor().clamp(0, from.length - 1)];
      used.add('$id.$i');
      return pool[i];
    }

    final lines = <String>[];

    if (h.uncertain && !h.engaged) {
      lines.add(pick('ack.unsure', _pool(_unsure, tone, (b) => b.unsure)));
      return Acknowledgement(lines, used);
    }
    if (!h.engaged && !h.correction && !h.disagreement) {
      return Acknowledgement.none;
    }

    final felt = h.felt;
    final contrast = Lexicon.contrast(h.feelings);
    final strongest = h.strongest;

    // The primary line: the most telling thing the author said.
    if (contrast != null) {
      final a = _cap(contrast.$1.word);
      final b = contrast.$2.word;
      lines.add('$a and $b, at once.');
      if (!terse) {
        lines.add(
          pick('ack.contrast', _pool(_contrast, tone, (m) => m.contrast)),
        );
      }
    } else if (felt.length >= 2 &&
        felt.map((f) => f.word).toSet().length >= 2) {
      final words = felt.map((f) => f.word).toSet().toList();
      lines.add('${_cap(words[0])} and ${words[1]}.');
      if (!terse) {
        lines.add(pick('ack.several', _pool(_several, tone, (m) => m.several)));
      }
    } else if (strongest != null) {
      lines.add(
        _fill(
          pick(
            'ack.felt.${strongest.intensity.name}',
            _feltPool(tone, strongest.intensity),
          ),
          {'W': _cap(strongest.word)},
        ),
      );
    } else if (h.denied.isNotEmpty) {
      lines.add(
        _fill(pick('ack.denied', _pool(_denied, tone, (b) => b.denied)), {
          'W': h.denied.first.word,
        }),
      );
    } else if (h.people.isNotEmpty) {
      lines.add(
        _fill(pick('ack.person', _pool(_person, tone, (b) => b.person)), {
          'N': Heard.first(h.people.first),
        }),
      );
    } else if (h.events.isNotEmpty) {
      lines.add(
        _fill(pick('ack.event', _pool(_event, tone, (b) => b.event)), {
          'E': h.events.first,
        }),
      );
    } else if (h.places.isNotEmpty) {
      lines.add(
        _fill(pick('ack.place', _pool(_place, tone, (b) => b.place)), {
          'P': h.places.first,
        }),
      );
    } else if (h.fears.isNotEmpty) {
      lines.add(_fill(_fear, {'x': h.fears.first}));
    } else if (h.wants.isNotEmpty) {
      lines.add(_fill(_want, {'x': h.wants.first}));
    } else if (h.values.isNotEmpty) {
      lines.add(_fill(_value, {'X': _cap(h.values.first)}));
    } else if (h.correction) {
      lines.add(
        pick('ack.correction', _pool(_correction, tone, (b) => b.correction)),
      );
    } else if (h.disagreement) {
      lines.add(
        pick(
          'ack.disagreement',
          _pool(_disagreement, tone, (b) => b.disagreement),
        ),
      );
    } else if (h.several) {
      lines.add(
        pick(
          'ack.possibilities',
          _pool(_possibilities, tone, (b) => b.possibilities),
        ),
      );
    } else if (h.kinds.any((k) => k.kind == 'kin')) {
      final k = h.kinds.firstWhere((k) => k.kind == 'kin');
      lines.add(
        _fill(pick('ack.kin', _pool(_kin, tone, (b) => b.kin)), {
          'K': _cap(k.word),
        }),
      );
    } else if (tail(h.text) != null) {
      // Nothing recognised by name: what was said last comes back, in the author's
      // own words, which says more than a stock line about a harbour or a funeral.
      lines.add(
        '${tail(h.text)}. ${pick('ack.echo', _pool(_echoTag, tone, (b) => b.echoTag))}',
      );
    } else if (h.kinds.isNotEmpty) {
      lines.add(
        _fill(pick('ack.kind', _pool(_kind, tone, (b) => b.kind)), {
          'K': _cap(h.kinds.first.word),
        }),
      );
    }

    // What the project says about someone just named, as what the author wrote.
    if (!terse &&
        h.people.isNotEmpty &&
        strongest == null &&
        contrast == null) {
      final name = h.people.first;
      final link = cues.links[name];
      final id = 'ack.link.${link ?? ''}.$name';
      if (link != null &&
          _link.containsKey(link) &&
          !recent.any((r) => r.startsWith(id))) {
        used.add('$id.0');
        lines.add(_fill(_link[link]!, {'N': Heard.first(name)}));
      }
    }
    // What the author wrote about a place just named.
    if (!terse &&
        h.places.isNotEmpty &&
        strongest == null &&
        contrast == null) {
      final place = h.places.first;
      final note = cues.placeNotes[place];
      final id = 'ack.note.$place';
      if (note != null && !recent.any((r) => r.startsWith(id))) {
        used.add('$id.0');
        lines.add(_fill(_placeNote, {'note': note}));
      }
    }
    return Acknowledgement(lines, used);
  }

  // --------------------------------------------------------------- reflecting

  /// A remark on the kind of feeling the author named, to say instead of asking, or
  /// before it. Null when no feeling was named.
  static String? reflection(
    Heard h, {
    ListenTone tone = ListenTone.neutral,
    required GenerationSeed seed,
    required int turn,
    List<String> recent = const [],
    List<String>? used,
  }) {
    final contrast = Lexicon.contrast(h.feelings);
    final shared = MannerShared.of(tone);
    final String id;
    final List<String> pool;
    if (contrast != null) {
      id = 'reflect.contrast';
      pool = shared?.contrast ?? _contrastReflections;
    } else if (h.strongest != null) {
      id = 'reflect.${h.strongest!.family.name}';
      pool =
          shared?.reflection(h.strongest!.family) ??
          _reflections[h.strongest!.family]!;
    } else {
      return null;
    }
    final fresh = [
      for (var i = 0; i < pool.length; i++)
        if (!recent.contains('$id.$i')) i,
    ];
    if (fresh.isEmpty) return null;
    final roll = seed.derive('listen/$id').unitAt(turn, fresh.length);
    final i = fresh[(roll * fresh.length).floor().clamp(0, fresh.length - 1)];
    used?.add('$id.$i');
    return pool[i];
  }

  // ----------------------------------------------------------------- recalling

  /// Something the author has said before, said again: "Fear again. You said that
  /// earlier too." Counts from the author's own turns in this conversation, so a
  /// remark that this is the third time is true. Null when nothing repeats, or one
  /// was made lately.
  static String? callback(
    Heard h,
    List<Heard> earlier, {
    ListenTone tone = ListenTone.neutral,
    required GenerationSeed seed,
    required int turn,
    List<String> recent = const [],
    List<String>? used,
  }) {
    if (earlier.isEmpty) return null;
    if (recent.any((r) => r.startsWith('callback.'))) return null;
    if (seed.derive('listen/callback').unitAt(turn, 7) > 0.75) return null;

    // What this answer is about, each as a key and the word to say it with.
    final keys = <String, String>{
      for (final f in h.felt) 'feeling:${f.family.name}': _cap(f.word),
      for (final p in h.people) 'person:$p': Heard.first(p),
      for (final e in h.events) 'event:$e': e,
      for (final p in h.places) 'place:$p': p,
    };
    if (keys.isEmpty) return null;

    Set<String> keysOf(Heard e) => {
      for (final f in e.felt) 'feeling:${f.family.name}',
      for (final p in e.people) 'person:$p',
      for (final ev in e.events) 'event:$ev',
      for (final p in e.places) 'place:$p',
    };

    String? best;
    var bestCount = 0;
    for (final k in keys.keys) {
      final times = earlier.where((e) => keysOf(e).contains(k)).length + 1;
      if (times >= 2 && times > bestCount) {
        best = k;
        bestCount = times;
      }
    }
    if (best == null) return null;
    final word = keys[best]!;
    used?.add('callback.$best.$bestCount');
    final shared = MannerShared.of(tone);
    return bestCount == 2
        ? _fill(shared?.back ?? _back, {'W': word})
        : _fill(shared?.backCount ?? _backCount, {
            'O': _ordinal(bestCount),
            'W': word.toLowerCase(),
          });
  }
}
