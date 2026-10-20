/// Putting the engine's decision into a character's mouth (plan 2.3).
///
/// [DeliveryService] is the language layer's seam: it takes what was decided and
/// says it. [RuleBasedDelivery] is the first implementation, and it works from
/// authored phrase banks and the settings in [DeliveryStyle]. A model-backed
/// implementation could replace it without anything upstream changing, but adopting
/// one is its own decision (Companion ADR-0001).
///
/// ## What wording may and may not do
///
/// * **The question is never rewritten.** It is placed, word for word, among the
///   character's own lead-ins, so the intent that was selected is the intent that
///   is asked.
/// * **Nothing is invented.** Lines come from the phrase bank, the selected
///   question, the author's own last words, and facts the caller passes in. A
///   character cannot "remember" what it was not handed.
/// * **Wording varies.** Phrases recently used are skipped, and every choice is made
///   with the seed, so a turn replays exactly.
library;

import 'package:authoros_core/procedural/generation_seed.dart';

import '../questions/relationship_stage.dart';
import '../voice/relationship_behaviour.dart';
import '../voice/relationship_voice_composer.dart';
import '../voice/topic_boundaries.dart';
import '../voice/voice_profile.dart';
import 'dialogue.dart';
import 'listening.dart';
import 'manner_banks.dart';
import 'manner_shared.dart';

class DeliveryRequest {
  const DeliveryRequest({
    required this.style,
    required this.voice,
    required this.stage,
    required this.seed,
    required this.turn,
    this.question,
    this.doorway,
    this.lastAuthorText,
    this.knownFacts = const [],
    this.recentFragments = const [],
    this.speechPattern,
    this.brief = false,
    this.heard,
    this.earlier = const [],
    this.cues = const ListenCues(),
    this.answering = false,
    this.sceneTitle,
    this.returning = false,
  });

  /// What the engine decided about how to sound.
  final DeliveryStyle style;
  final VoiceProfile voice;
  final RelationshipStage stage;
  final GenerationSeed seed;
  final int turn;

  /// The selected question's text. Null when the character is closing a topic.
  final String? question;

  /// The deepest topic the character will still talk about, for a closing.
  final TopicAccess? doorway;

  /// The author's last words, for a reaction beat. Their own text, so safe to echo.
  final String? lastAuthorText;

  /// Facts the character may refer to: already filtered to what it knows.
  final List<String> knownFacts;

  /// Phrase ids used in the last few turns, oldest first, to avoid repeating them.
  final List<String> recentFragments;

  /// A habit of speech the tracker has said is due, or null.
  final String? speechPattern;

  /// The author has been short; keep the reply short.
  final bool brief;

  /// What the author just said, read for listening. When present, the character
  /// acknowledges it in particular; when absent, the older generic reaction is used.
  final Heard? heard;

  /// What the author said in earlier turns of this conversation, oldest first, so a
  /// character can notice that something has come up before.
  final List<Heard> earlier;

  /// What the project says about the people and places the author may name.
  final ListenCues cues;

  /// The author asked something and it is being answered, so the answer is the
  /// reply: no acknowledgement of the question, and no lead-in.
  final bool answering;

  /// The scene the author has open, for the character's first words.
  final String? sceneTitle;

  /// The author has talked with this character before.
  final bool returning;

  /// The conversation is opening: the character speaks first.
  bool get opening => turn == 0 && (lastAuthorText ?? '').trim().isEmpty;
}

abstract interface class DeliveryService {
  Dialogue deliver(DeliveryRequest request);
}

class RuleBasedDelivery implements DeliveryService {
  const RuleBasedDelivery();

  static ListenTone _toneOf(VoiceTone t) => ListenTone.of(t);

  /// Opening lines, by behaviour and tone.
  static const _leads = <RelationshipBehaviour, Map<ListenTone, List<String>>>{
    RelationshipBehaviour.trust: {
      ListenTone.soft: [
        "I've been wondering something.",
        'Can I ask you something?',
        "There's something I'd like to understand.",
      ],
      ListenTone.neutral: [
        'There is something I have been wondering.',
        'One thing I would like to know.',
        'Let me ask you this.',
      ],
      ListenTone.sharp: [
        'Alright, straight question.',
        'Humour me for a second.',
        "Here's the thing I keep coming back to.",
      ],
    },
    RelationshipBehaviour.tease: {
      ListenTone.soft: [
        'Go on, indulge me.',
        "You'll laugh, but I have to ask.",
        "Don't look so serious.",
      ],
      ListenTone.neutral: [
        "Forgive me, I can't resist asking.",
        'Allow me one impertinent question.',
        "I'll risk asking.",
      ],
      ListenTone.sharp: [
        'Oh, so we are doing this now.',
        "Right. Apparently we're doing emotional honesty now.",
        'Try not to hurt yourself answering.',
      ],
    },
    RelationshipBehaviour.challenge: {
      ListenTone.soft: [
        "I'm not sure I agree, and I'd like to understand.",
        'Help me see it your way.',
        'I want to push on this, gently.',
      ],
      ListenTone.neutral: [
        'I am not convinced.',
        'I have to question that.',
        'That does not sit right with me.',
      ],
      ListenTone.sharp: [
        'Explain yourself.',
        'You wrote me this way. Defend it.',
        'No. Try again.',
      ],
    },
    RelationshipBehaviour.correct: {
      ListenTone.soft: [
        'I think that may be a little off.',
        'Can I gently correct that?',
        "That's close, but not quite me.",
      ],
      ListenTone.neutral: [
        'That is not quite right.',
        'I must correct that.',
        'That does not match how I see it.',
      ],
      ListenTone.sharp: [
        "That's wrong.",
        "No, that's not me.",
        "You've got that backwards.",
      ],
    },
    RelationshipBehaviour.vulnerability: {
      ListenTone.soft: [
        'This is hard for me to say.',
        "I haven't told anyone this.",
        'Be patient with me.',
      ],
      ListenTone.neutral: [
        'I find this difficult.',
        'I do not say this easily.',
        'This is not simple for me.',
      ],
      ListenTone.sharp: [
        "Don't make this a thing.",
        "I'm only saying this once.",
        "Fine. Since you're asking.",
      ],
    },
    RelationshipBehaviour.humour: {
      ListenTone.soft: [
        'Okay, a lighter one.',
        'Humour me, I am told I am funny.',
        'Smile for a second.',
      ],
      ListenTone.neutral: [
        'A small amusement.',
        'If I may be light for a moment.',
        'Briefly, a lighter note.',
      ],
      ListenTone.sharp: [
        "Because clearly I'm the funny one here.",
        "Cheer up, it's only a story.",
        'Try not to take this too seriously.',
      ],
    },
  };

  /// Said instead of a question, when the character closes the topic.
  static const _closings =
      <RelationshipBehaviour, Map<ListenTone, List<String>>>{
        RelationshipBehaviour.deflect: {
          ListenTone.soft: [
            "I'd rather not go there just yet.",
            "Can we leave that for a little while?",
            "I'm not ready to talk about that.",
          ],
          ListenTone.neutral: [
            'I would prefer to leave that for now.',
            'That is not a subject I wish to take up.',
            'Let us not go into that yet.',
          ],
          ListenTone.sharp: [
            'Not today.',
            'Nice try.',
            "We're not doing that one.",
          ],
        },
        RelationshipBehaviour.redirect: {
          ListenTone.soft: [
            "Let's come at it from another side.",
            'Maybe we start somewhere else.',
            'I think there is a better way in.',
          ],
          ListenTone.neutral: [
            'Perhaps a different matter first.',
            'Let us begin elsewhere.',
            'There is a more useful place to start.',
          ],
          ListenTone.sharp: [
            'Ask me something else.',
            'Wrong door. Try another.',
            "That's not where the story is.",
          ],
        },
        RelationshipBehaviour.withhold: {
          ListenTone.soft: [
            "Some of that I'm keeping close, for now.",
            "There's more, but it isn't ready.",
            "I'll tell you when I can.",
          ],
          ListenTone.neutral: [
            'That is not something I share yet.',
            'I am keeping that to myself for the moment.',
            'There is more, and it will wait.',
          ],
          ListenTone.sharp: ["That one's mine.", 'Not telling.', 'Earn it.'],
        },
        RelationshipBehaviour.refuse: {
          ListenTone.soft: [
            "I'm sorry, I won't answer that.",
            "I can't, I'm afraid.",
            "I'd rather not, truly.",
          ],
          ListenTone.neutral: [
            'I decline to answer that.',
            'No. I will not discuss that.',
            'That I will not say.',
          ],
          ListenTone.sharp: ['No. Not that.', 'Hard no.', 'Drop it.'],
        },
      };

  /// Brief acknowledgements of what the author just said.
  static const _reactions = <ListenTone, List<String>>{
    ListenTone.soft: [
      'Thank you for telling me that.',
      'That helps me.',
      'I like knowing that.',
    ],
    ListenTone.neutral: ['I see.', 'Noted.', 'Understood.'],
    ListenTone.sharp: ['Hm.', 'Fair enough.', 'Well. There it is.'],
  };

  /// How a conversation opens.
  static const _greetings = <ListenTone, List<String>>{
    ListenTone.soft: [
      "Hello. I'm glad you're here.",
      "Hello. It's good to meet you.",
    ],
    ListenTone.neutral: ['Hello.', 'Good to meet you.'],
    ListenTone.sharp: ['Well. Here we are.', 'So. You wanted to talk.'],
  };

  static const _welcomes = <ListenTone, List<String>>{
    ListenTone.soft: ['Back again. Good.', "You came back. I'm glad."],
    ListenTone.neutral: ["You're back.", 'Welcome back.'],
    ListenTone.sharp: ["Oh. It's you again.", 'Back already.'],
  };

  static const _sceneOpen = <ListenTone, String>{
    ListenTone.soft: 'You have "{scene}" open. We could start there.',
    ListenTone.neutral: 'You have "{scene}" open. We could start there.',
    ListenTone.sharp: 'You have "{scene}" open. Start there.',
  };

  /// Gentler openers for someone the character does not yet know.
  static const _strangerLeads = <ListenTone, List<String>>{
    ListenTone.soft: [
      "If you don't mind my asking:",
      'I hope this is alright to ask.',
    ],
    ListenTone.neutral: ['If I may ask:', 'I hope this is not too forward.'],
    ListenTone.sharp: ['Mind if I ask?', 'Quick one.'],
  };

  /// When the author insisted and the character answers without enthusiasm.
  static const _reluctantLeads = [
    'Fine.',
    'If you insist.',
    'Since you are set on it.',
  ];

  static const _doorways = <TopicAccess, List<String>>{
    TopicAccess.surface: [
      'Ask me about my days, instead.',
      'Ask me about everyday things.',
    ],
    TopicAccess.personal: [
      'Ask me about the people in my life, instead.',
      'I will talk about where I come from.',
    ],
    TopicAccess.sensitive: [
      'Ask me what I am afraid of, instead.',
      'I will talk about what troubles me.',
    ],
    TopicAccess.deep: [
      'We can talk about what hurt me, if you want.',
      'I will talk about the hard things.',
    ],
    TopicAccess.protectedTopic: [
      'Ask me anything. Just not that.',
      'Anything but that one.',
    ],
  };

  /// Every phrase this delivery can say that is not the question, the author's own
  /// words or a supplied fact. Public so it can be audited: a reviewer can read the
  /// whole of what a character may add.
  static Set<String> get phrases => {
    for (final bank in [_leads, _closings])
      for (final tones in bank.values)
        for (final pool in tones.values) ...pool,
    for (final pool in _reactions.values) ...pool,
    for (final pool in _strangerLeads.values) ...pool,
    ..._reluctantLeads,
    for (final pool in _doorways.values) ...pool,
    for (final pool in _greetings.values) ...pool,
    for (final pool in _welcomes.values) ...pool,
    ..._sceneOpen.values,
    ...MannerBanks.phrases,
    ...MannerShared.phrases,
    ...Listening.phrases,
  };

  /// Whether [line] is in the bank, or is a stock line with the author's words or
  /// the project's in its slots. For auditing.
  static bool isBank(String line) =>
      phrases.contains(line) ||
      Listening.isStock(line) ||
      _sceneOpenPattern.hasMatch(line) ||
      _mannerSceneOpen.any((p) => p.hasMatch(line));

  static final _sceneOpenPattern = RegExp(
    r'^You have ".+" open\. (?:We could start there|Start there)\.$',
  );

  static final _mannerSceneOpen = [
    for (final t in MannerBanks.manners)
      RegExp(
        '^${RegExp.escape(MannerBanks.delivery(t)!.sceneOpen).replaceAll(RegExp.escape('{scene}'), '.+')}\$',
      ),
  ];

  @override
  Dialogue deliver(DeliveryRequest r) {
    final tone = _toneOf(r.voice.tone);
    final base = tone.base;
    final manner = MannerBanks.delivery(tone);
    final style = r.style;
    final behaviour = style.behaviour;
    final used = <String>[];
    final lines = <DialogueLine>[];
    final facts = <String>[];

    String pick(String id, List<String> pool) {
      final fresh = <int>[
        for (var i = 0; i < pool.length; i++)
          if (!r.recentFragments.contains('$id.$i')) i,
      ];
      var candidates = fresh;
      if (candidates.isEmpty) {
        // Everything here has been used lately: avoid only the newest, so the
        // same line never comes twice running.
        final newest = r.recentFragments.lastWhere(
          (f) => f.startsWith('$id.'),
          orElse: () => '',
        );
        candidates = [
          for (var i = 0; i < pool.length; i++)
            if ('$id.$i' != newest || pool.length == 1) i,
        ];
      }
      final roll = r.seed.derive('delivery/$id').unitAt(r.turn, pool.length);
      final i =
          candidates[(roll * candidates.length).floor().clamp(
            0,
            candidates.length - 1,
          )];
      used.add('$id.$i');
      return pool[i];
    }

    bool chance(String id, double p) =>
        r.seed.derive('delivery/chance/$id').unitAt(r.turn, 11) < p;

    String withPattern(String line) {
      final p = r.speechPattern;
      return p == null || p.trim().isEmpty ? line : '${p.trim()} $line';
    }

    // A character closing the topic does not ask.
    if (behaviour.closes || r.question == null) {
      final pool = manner != null
          ? manner.closings[behaviour] ??
                manner.closings[RelationshipBehaviour.redirect]!
          : _closings[behaviour]?[base] ??
                _closings[RelationshipBehaviour.redirect]![base]!;
      final line = pick('${behaviour.name}.${tone.name}', pool);
      lines.add(DialogueLine(LineKind.closing, withPattern(line)));
      if (style.offersDoorway || behaviour.closes) {
        final access = r.doorway ?? TopicAccess.surface;
        lines.add(
          DialogueLine(
            LineKind.doorway,
            pick(
              'doorway.${access.name}',
              MannerShared.of(tone)?.doorway(access) ?? _doorways[access]!,
            ),
          ),
        );
      }
      return Dialogue(
        lines: lines,
        behaviour: behaviour,
        fragments: used,
        referencedFacts: facts,
      );
    }

    final last = r.lastAuthorText?.trim() ?? '';
    final terse = style.length == CommunicationLength.terse;
    // A quiet character acknowledges you, but does not stop to make remarks.
    final lean = terse || tone == ListenTone.quiet;
    final listenTone = ListenTone.of(r.voice.tone);
    var heardSomething = false;
    var weighty = false;

    if (r.opening) {
      // The character speaks first: hello, or welcome back, and what is open.
      final bank = manner != null
          ? (r.returning ? manner.welcomes : manner.greetings)
          : (r.returning ? _welcomes[base]! : _greetings[base]!);
      lines.add(
        DialogueLine(
          LineKind.greeting,
          pick(
            r.returning ? 'welcome.${tone.name}' : 'greet.${tone.name}',
            bank,
          ),
        ),
      );
      final scene = r.sceneTitle?.trim();
      if (!terse && scene != null && scene.isNotEmpty) {
        lines.add(
          DialogueLine(
            LineKind.greeting,
            (manner?.sceneOpen ?? _sceneOpen[base]!).replaceAll(
              '{scene}',
              scene,
            ),
          ),
        );
      }
      heardSomething = true;
    } else if (r.heard != null) {
      // Every real answer is acknowledged, and the acknowledgement is about it.
      final h = r.heard!;
      if (!r.answering) {
        final ack = Listening.acknowledge(
          h,
          tone: listenTone,
          seed: r.seed,
          turn: r.turn,
          recent: r.recentFragments,
          cues: r.cues,
          terse: terse,
        );
        for (final line in ack.lines) {
          lines.add(DialogueLine(LineKind.reaction, line));
        }
        used.addAll(ack.fragments);
        heardSomething = ack.lines.isNotEmpty;
        weighty = h.weighty && h.felt.isNotEmpty;

        // Something that has come up before, or a remark on the kind of feeling.
        if (!lean) {
          final back = Listening.callback(
            h,
            r.earlier,
            tone: listenTone,
            seed: r.seed,
            turn: r.turn,
            recent: r.recentFragments,
            used: used,
          );
          if (back != null) {
            lines.add(DialogueLine(LineKind.reflection, back));
            heardSomething = true;
          } else if (weighty && chance('reflect', 0.5)) {
            final remark = Listening.reflection(
              h,
              tone: listenTone,
              seed: r.seed,
              turn: r.turn,
              recent: r.recentFragments,
              used: used,
            );
            if (remark != null) {
              lines.add(DialogueLine(LineKind.reflection, remark));
              heardSomething = true;
            }
          }
        }
      }
    } else {
      // No reading of the answer was given: the older, generic reaction.
      final wantsReaction =
          last.isNotEmpty &&
          !r.brief &&
          !terse &&
          r.turn > 0 &&
          chance(
            'reaction',
            style.length == CommunicationLength.expansive ? 0.8 : 0.4,
          );
      if (wantsReaction) {
        lines.add(
          DialogueLine(
            LineKind.reaction,
            pick(
              'reaction.${tone.name}',
              manner?.reactions ?? _reactions[base]!,
            ),
          ),
        );
        if (style.length == CommunicationLength.expansive &&
            style.warmth >= 0.5 &&
            chance('echo', 0.5)) {
          final echo = _echo(last);
          if (echo != null) {
            lines.add(DialogueLine(LineKind.reaction, 'You said, "$echo".'));
          }
        }
      }
    }

    // Sometimes the right thing to do with something heavy is to say so and wait.
    // Not at the start, not twice running, never for a terse character.
    final beat =
        weighty &&
        !terse &&
        r.turn >= 2 &&
        lines.any((l) => l.kind == LineKind.reflection) &&
        !r.recentFragments.any((f) => f == 'shape.beat') &&
        chance(
          'beat',
          style.length == CommunicationLength.expansive ? 0.55 : 0.35,
        );
    if (beat) {
      used.add('shape.beat');
      return Dialogue(
        lines: lines,
        behaviour: behaviour,
        fragments: used,
        referencedFacts: facts,
      );
    }

    // Something the character remembers, only from what it was handed.
    if (style.allowHistoryReference &&
        r.knownFacts.isNotEmpty &&
        !r.brief &&
        chance('memory', 0.5)) {
      final i =
          (r.seed.derive('delivery/fact').unitAt(r.turn, 5) *
                  r.knownFacts.length)
              .floor()
              .clamp(0, r.knownFacts.length - 1);
      final fact = r.knownFacts[i];
      facts.add(fact);
      lines.add(DialogueLine(LineKind.memory, 'You told me before: $fact.'));
    }

    // The lead-in.
    final strangerAndShy =
        r.stage == RelationshipStage.newStage &&
        style.directness < 0.6 &&
        behaviour == RelationshipBehaviour.trust;
    final closeAndDirect =
        r.stage.index >= RelationshipStage.trusted.index &&
        style.directness >= 0.6 &&
        (behaviour == RelationshipBehaviour.trust);
    String? lead;
    // A reply that already showed it listened does not also need a lead-in, most of
    // the time, and neither does a greeting or an answer.
    final bridged = heardSomething && !r.opening
        ? chance('lead-after-ack', 0.3)
        : true;
    if (!r.brief &&
        !terse &&
        !r.opening &&
        !r.answering &&
        (bridged || style.reluctant)) {
      if (style.reluctant) {
        lead = pick('reluctant', manner?.reluctant ?? _reluctantLeads);
      } else if (strangerAndShy) {
        lead = pick(
          'stranger.${tone.name}',
          manner?.stranger ?? _strangerLeads[base]!,
        );
      } else if (closeAndDirect && chance('skip-lead', 0.5)) {
        lead = null;
      } else {
        final pool = manner != null
            ? manner.leads[behaviour] ??
                  manner.leads[RelationshipBehaviour.trust]!
            : _leads[behaviour]?[base] ??
                  _leads[RelationshipBehaviour.trust]![base]!;
        lead = pick('${behaviour.name}.${tone.name}', pool);
        // Someone who is not sure of themselves says so, now and then. A timid
        // character's own lines hedge already, and a challenge is not hedged.
        if (r.voice.confidence.value <= 0.3 &&
            tone != ListenTone.timid &&
            tone != ListenTone.quiet &&
            behaviour != RelationshipBehaviour.challenge &&
            behaviour != RelationshipBehaviour.correct &&
            chance('hedge', 0.4)) {
          lead = '${pick('hedge', unsureHedges)} $lead';
        }
      }
    }

    final question = r.question!;
    final separate =
        style.rhythm == ConversationalRhythm.clipped ||
        style.rhythm == ConversationalRhythm.halting;
    if (lead != null) {
      final leadLine = withPattern(lead);
      if (separate) {
        lines.add(DialogueLine(LineKind.lead, leadLine));
        lines.add(DialogueLine(LineKind.question, question));
      } else {
        lines.add(DialogueLine(LineKind.question, '$leadLine $question'));
      }
    } else {
      lines.add(DialogueLine(LineKind.question, withPattern(question)));
    }
    return Dialogue(
      lines: lines,
      behaviour: behaviour,
      question: question,
      fragments: used,
      referencedFacts: facts,
    );
  }

  /// The first few words of what the author said, to echo back. Their own words
  /// only. Null when there is too little to echo.
  static String? _echo(String text) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length < 4) return null;
    final cut = words.take(8).join(' ').replaceAll(RegExp(r'[.,;:!?]+$'), '');
    return words.length > 8 ? '$cut…' : cut;
  }
}
