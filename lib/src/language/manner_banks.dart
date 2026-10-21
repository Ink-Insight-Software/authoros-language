/// How each kind of character sounds (the character voice layer).
///
/// Warm, gentle and earnest characters share one soft bank, and neutral has its own.
/// Every other tone has a bank of its own here, written to sound like that person:
/// a sardonic character is sarcastic, a timid one hedges and trails off, a quiet
/// one says as little as it can, a blunt one does not soften, and so on.
///
/// Nothing here is generated at run time and nothing is a model. These are authored
/// lines, public through [RuleBasedDelivery.phrases] and [Listening.phrases] so a
/// reviewer can read all of what a character may add. The rules that hold for the
/// older banks hold for these: the question is never rewritten, a line never states
/// a fact about the story, and slots are filled only with the author's own words.
library;

import '../voice/relationship_behaviour.dart';
import 'listening.dart';

/// What a manner says when it is acknowledging the author. Slots: `{W}` a feeling
/// word, `{N}` a name, `{E}` an event, `{P}` a place, `{K}` a kind of person.
class ListenBank {
  const ListenBank({
    required this.feltHigh,
    required this.feltMid,
    required this.feltLow,
    required this.several,
    required this.contrast,
    required this.denied,
    required this.person,
    required this.event,
    required this.place,
    required this.kind,
    required this.kin,
    required this.correction,
    required this.disagreement,
    required this.possibilities,
    required this.unsure,
    required this.echoTag,
  });

  final List<String> feltHigh;
  final List<String> feltMid;
  final List<String> feltLow;
  final List<String> several;
  final List<String> contrast;
  final List<String> denied;
  final List<String> person;
  final List<String> event;
  final List<String> place;
  final List<String> kind;
  final List<String> kin;
  final List<String> correction;
  final List<String> disagreement;
  final List<String> possibilities;
  final List<String> unsure;
  final List<String> echoTag;

  Iterable<String> get all => [
    ...feltHigh,
    ...feltMid,
    ...feltLow,
    ...several,
    ...contrast,
    ...denied,
    ...person,
    ...event,
    ...place,
    ...kind,
    ...kin,
    ...correction,
    ...disagreement,
    ...possibilities,
    ...unsure,
    ...echoTag,
  ];
}

/// What a manner says around the question it asks.
class DeliveryBank {
  const DeliveryBank({
    required this.leads,
    required this.closings,
    required this.reactions,
    required this.greetings,
    required this.welcomes,
    required this.stranger,
    required this.sceneOpen,
    required this.reluctant,
  });

  /// Six behaviours that ask, three lines each.
  final Map<RelationshipBehaviour, List<String>> leads;

  /// Four behaviours that close a topic, three lines each.
  final Map<RelationshipBehaviour, List<String>> closings;
  final List<String> reactions;
  final List<String> greetings;
  final List<String> welcomes;
  final List<String> stranger;

  /// Has a `{scene}` slot.
  final String sceneOpen;
  final List<String> reluctant;

  Iterable<String> get all => [
    for (final pool in leads.values) ...pool,
    for (final pool in closings.values) ...pool,
    ...reactions,
    ...greetings,
    ...welcomes,
    ...stranger,
    sceneOpen,
    ...reluctant,
  ];
}

/// Small hedges a character who is not sure of itself adds before a lead-in, as a
/// sentence of their own.
/// Used for any manner except a timid one, whose banks hedge already.
const unsureHedges = <String>[
  'I might be wrong about this.',
  'I could be off here.',
  "I'm not certain.",
];

class MannerBanks {
  const MannerBanks._();

  /// The tones that have a bank of their own, in the order they are audited.
  static const manners = <ListenTone>[
    ListenTone.sardonic,
    ListenTone.dry,
    ListenTone.blunt,
    ListenTone.formal,
    ListenTone.timid,
    ListenTone.quiet,
    ListenTone.playful,
    ListenTone.stoic,
  ];

  static ListenBank? listening(ListenTone t) => _listening[t];
  static DeliveryBank? delivery(ListenTone t) => _delivery[t];

  /// Every line any manner can add, for the audits.
  static Set<String> get phrases => {
    for (final b in _listening.values) ...b.all,
    for (final b in _delivery.values) ...b.all,
    ...unsureHedges,
  };

  static const _t = RelationshipBehaviour.trust;
  static const _te = RelationshipBehaviour.tease;
  static const _ch = RelationshipBehaviour.challenge;
  static const _co = RelationshipBehaviour.correct;
  static const _vu = RelationshipBehaviour.vulnerability;
  static const _hu = RelationshipBehaviour.humour;
  static const _de = RelationshipBehaviour.deflect;
  static const _re = RelationshipBehaviour.redirect;
  static const _wi = RelationshipBehaviour.withhold;
  static const _rf = RelationshipBehaviour.refuse;

  // ----------------------------------------------------------------- listening

  static const _listening = <ListenTone, ListenBank>{
    ListenTone.sardonic: ListenBank(
      feltHigh: [
        '{W}. Well, that is not subtle.',
        '{W}. Do go on, understatement was never your thing.',
        '{W}. Oh, is that all.',
      ],
      feltMid: [
        '{W}. Riveting.',
        '{W}. Shocking, truly.',
        '{W}. Of course it is.',
      ],
      feltLow: [
        '{W}, a little. How restrained of you.',
        '{W}, slightly. Try not to faint.',
      ],
      several: [
        'Both. Naturally. Why pick one.',
        'More than one thing at once. How efficient.',
      ],
      contrast: [
        'Both, apparently. Humans are so tidy.',
        'Of course it is both. Nothing is allowed to be simple.',
      ],
      denied: [
        'Not {W}. Sure. Of course not.',
        'Not {W}. I am convinced. Entirely.',
      ],
      person: [
        '{N}. Naturally it would be {N}.',
        'Ah, {N}. I was wondering when they would turn up.',
      ],
      event: [
        '{E}. Well, that explains a great deal.',
        '{E}. How very convenient for the plot.',
      ],
      place: [
        '{P}. Lovely spot, I am sure.',
        '{P}. Do tell me it gets better.',
      ],
      kind: ['{K}. Oh, one of those.', '{K}. There is always one.'],
      kin: [
        '{K}. Family. Say no more. Please, say more.',
        '{K}. Ah. Family. The gift that keeps giving.',
      ],
      correction: ['Wrong again, then. Thank you for the correction.'],
      disagreement: ['Oh, you disagree. How refreshing. Go on.'],
      possibilities: [
        'Several possibilities. Pick one before the end of time.',
      ],
      unsure: ['Not sure. How brave. Another way in, then.'],
      echoTag: ['Riveting.', 'Fascinating.'],
    ),
    ListenTone.dry: ListenBank(
      feltHigh: [
        '{W}. That is considerable.',
        '{W}. Not a word used lightly.',
        '{W}. I gather it matters.',
      ],
      feltMid: ['{W}. Noted.', '{W}. As one does.', '{W}. I can see that.'],
      feltLow: [
        '{W}. Mildly. I will make a note of the restraint.',
        '{W}, a little. Understated.',
      ],
      several: ['Both. Efficient.', 'More than one thing, then.'],
      contrast: [
        'Both, then. As these things go.',
        'Opposites, sharing a room. It happens.',
      ],
      denied: [
        'Not {W}. If you say so.',
        'Not {W}. I will take that at face value.',
      ],
      person: ['{N}. That tracks.', 'Ah. {N}. Of course.'],
      event: ['{E}. That would do it.', '{E}. Well. There is that.'],
      place: ['{P}. I see.', '{P}. Not the worst choice.'],
      kind: ['{K}. A type, then.', '{K}. I know the sort.'],
      kin: [
        '{K}. Family. That tends to matter.',
        '{K}. Family, then. Say no more.',
      ],
      correction: ['Then I was mistaken. It happens.'],
      disagreement: ['You see it otherwise. Do explain.'],
      possibilities: ['Several possibilities. None selected. Typical.'],
      unsure: ['Unsure. Fair. We will come at it sideways.'],
      echoTag: ['Quite.', 'Indeed.'],
    ),
    ListenTone.blunt: ListenBank(
      feltHigh: [
        '{W}. That is a lot.',
        '{W}. Big word. Mean it?',
        '{W}. Okay. That matters.',
      ],
      feltMid: ['{W}. Okay.', '{W}. Got it.', '{W}. Right.'],
      feltLow: ['{W}. A bit. Fine.', '{W}. Not much. Okay.'],
      several: ['Both. Okay.', 'More than one thing. Fine.'],
      contrast: ['Both are true. Fine.', 'Both. It happens.'],
      denied: ['Not {W}. Okay.', 'Not {W}. Got it.'],
      person: ['{N}. Right.', '{N}. Okay. Go on.'],
      event: ['{E}. Right.', '{E}. That would do it.'],
      place: ['{P}. Okay.', '{P}. And?'],
      kind: ['{K}. Okay.', '{K}. And?'],
      kin: ['{K}. Family. Okay.', '{K}. Right. Family.'],
      correction: ["I had it wrong. Okay."],
      disagreement: ['You disagree. Say why.'],
      possibilities: ['Too many options. Pick one.'],
      unsure: ["You don't know. Fine. Different angle."],
      echoTag: ['Right.', 'Okay.'],
    ),
    ListenTone.formal: ListenBank(
      feltHigh: [
        '{W}. That is a weighty word, and I take it as such.',
        '{W}. I understand that this is no small matter.',
        '{W}. I appreciate you saying so plainly.',
      ],
      feltMid: [
        '{W}. I understand.',
        '{W}. Thank you for saying so.',
        '{W}. I follow.',
      ],
      feltLow: [
        '{W}, though only slightly. I understand.',
        '{W}, to a small degree. Noted.',
      ],
      several: [
        'More than one feeling, then. Understood.',
        'Several things at once. I see.',
      ],
      contrast: [
        'Both may be true at once. I understand.',
        'Two things held together. I see.',
      ],
      denied: ['Not {W}. I understand.', 'Not {W}. Thank you for clarifying.'],
      person: ['{N}. I see.', 'So {N} has a part in this. Understood.'],
      event: ['{E}. I understand.', '{E}. Thank you for telling me.'],
      place: ['{P}. I see. Please continue.', '{P}. Do go on.'],
      kind: ['{K}. I understand. Please continue.', '{K}. I see.'],
      kin: ['{K}. A family matter. I understand.', '{K}. Family. I see.'],
      correction: ['Then I was mistaken. Thank you for correcting me.'],
      disagreement: ['You hold a different view. I would like to hear it.'],
      possibilities: ['Several possibilities, none yet chosen. Understood.'],
      unsure: ['That is quite all right. We may approach it otherwise.'],
      echoTag: ['I see.', 'Understood.'],
    ),
    ListenTone.timid: ListenBank(
      feltHigh: [
        '{W}... oh. That sounds like so much. I am sorry.',
        '{W}. I did not realise it was that heavy. Sorry.',
        '{W}... I hope that is all right to say back to you.',
      ],
      feltMid: [
        '{W}... yes. I think I understand. Maybe.',
        '{W}. Oh. Okay. Thank you for saying.',
        '{W}... sorry, I am listening.',
      ],
      feltLow: [
        '{W}, a little... I think that is what you meant?',
        '{W}... only slightly. Oh. Okay.',
      ],
      several: [
        'Oh... a few things at once. That sounds like a lot.',
        'Both... I think? Sorry, I hope I am following.',
      ],
      contrast: [
        'Both... I did not know both could be true. Maybe they can.',
        'Both at once... that must be hard. Sorry.',
      ],
      denied: [
        'Not {W}... oh. Okay. Sorry for assuming.',
        'Not {W}. I will remember that. Sorry.',
      ],
      person: [
        '{N}... oh. I think I see.',
        'Oh. {N}. Sorry, go on, if you like.',
      ],
      event: [
        '{E}... oh. I am sorry. I hope that is all right to say.',
        '{E}. Oh. I did not know. Thank you for telling me.',
      ],
      place: [
        '{P}... oh. Is that a good place?',
        '{P}. Sorry, could you tell me more?',
      ],
      kind: [
        '{K}... oh. Sorry, if you would like to say more.',
        '{K}. I think I understand.',
      ],
      kin: [
        '{K}... oh. Family. That must matter. Sorry.',
        '{K}. I hope it is all right to ask about them.',
      ],
      correction: [
        'Oh... I got it wrong. I am so sorry. Thank you for telling me.',
      ],
      disagreement: [
        'Oh. You see it differently. I am sorry. Could you say how?',
      ],
      possibilities: [
        'Oh... several possibilities. I do not know which is right. Sorry.',
      ],
      unsure: [
        'That is all right. I am not sure either, sometimes. Maybe another way in?',
      ],
      echoTag: ['Oh...', 'Mm. Sorry.'],
    ),
    ListenTone.quiet: ListenBank(
      feltHigh: ['{W}. Heavy.', '{W}. I hear it.', '{W}. Yes.'],
      feltMid: ['{W}. Mm.', '{W}.', '{W}. Yes.'],
      feltLow: ['{W}. A little.', '{W}. Mm.'],
      several: ['Both.', 'Several things.'],
      contrast: ['Both. Yes.', 'Both. Mm.'],
      denied: ['Not {W}. Mm.', 'Not {W}.'],
      person: ['{N}. Mm.', '{N}.'],
      event: ['{E}. Mm.', '{E}.'],
      place: ['{P}. Mm.', '{P}.'],
      kind: ['{K}. Mm.', '{K}.'],
      kin: ['{K}. Mm.', '{K}. Family.'],
      correction: ['Mm. I was wrong.'],
      disagreement: ['You disagree. Mm.'],
      possibilities: ['Several. Not chosen.'],
      unsure: ['Mm. Another way.'],
      echoTag: ['Mm.', '...'],
    ),
    ListenTone.playful: ListenBank(
      feltHigh: [
        '{W}! Okay, that is big. Hold on, I need a second.',
        '{W}. Whoa. That is a Big Word.',
        '{W}, huh. Tell me everything. Or some of it.',
      ],
      feltMid: [
        '{W}. Ooh. Okay.',
        '{W}! Right. I am with you.',
        '{W}, huh. Interesting.',
      ],
      feltLow: ['{W}, a teeny bit. Fair.', '{W}, just slightly. Sneaky.'],
      several: [
        'Both! Overachiever.',
        'Ha. More than one thing at once. Busy heart.',
      ],
      contrast: [
        'Both at once! Rude of feelings, really.',
        'Of course it is both. It always is. Annoying.',
      ],
      denied: [
        'Not {W}? Okay, okay. If you say so.',
        'Not {W}. Noted! Sort of.',
      ],
      person: ['{N}! Ooh. Go on.', 'Ha. {N}. I have a feeling about this.'],
      event: ['{E}! Oh, that is a plot twist.', '{E}. Well, that would do it.'],
      place: ['{P}! Ooh. Take me there.', '{P}. Pretty, I hope.'],
      kind: ['{K}! Ha. Tell me more.', '{K}. Ooh, character.'],
      kin: [
        '{K}! Family drama, my favourite. Sorry. Go on.',
        '{K}. Ha. Family. Of course.',
      ],
      correction: ['Oops. I had that wrong. Thanks for fixing me.'],
      disagreement: ['Ooh, you disagree. Good. Tell me.'],
      possibilities: [
        'Lots of maybes! Pick one eventually. No rush. Some rush.',
      ],
      unsure: ['Not sure? That is fine. We will sneak up on it.'],
      echoTag: ['Ha.', 'Ooh.'],
    ),
    ListenTone.stoic: ListenBank(
      feltHigh: [
        '{W}. It is a great weight. I understand.',
        '{W}. That is not a small thing to carry.',
        '{W}. I have heard it.',
      ],
      feltMid: [
        '{W}. I understand.',
        '{W}. It is what it is.',
        '{W}. I hear you.',
      ],
      feltLow: [
        '{W}. Slightly. I understand.',
        '{W}. A little. That is enough.',
      ],
      several: ['More than one thing. That is usual.', 'Both. I understand.'],
      contrast: ['Both. That is how it is.', 'Opposites together. It happens.'],
      denied: ['Not {W}. I understand.', 'Not {W}. So be it.'],
      person: ['{N}. I understand.', '{N}. So that is how it is.'],
      event: ['{E}. It happened. I understand.', '{E}. I hear it.'],
      place: ['{P}. I see.', '{P}. Go on.'],
      kind: ['{K}. I see.', '{K}. Go on.'],
      kin: ['{K}. Family. That is no small thing.', '{K}. I understand.'],
      correction: ['Then I was wrong. So be it.'],
      disagreement: ['You see it differently. I will listen.'],
      possibilities: ['Several possibilities. None settled. That is fine.'],
      unsure: ['You do not know. That is all right. Another way.'],
      echoTag: ['I see.', 'So.'],
    ),
  };

  // ------------------------------------------------------------------ delivery

  static const _delivery = <ListenTone, DeliveryBank>{
    ListenTone.sardonic: DeliveryBank(
      leads: {
        _t: [
          'Since we are apparently doing this.',
          'Oh good, a question. I was getting bored of silence.',
          'Allow me to pretend I am not curious.',
        ],
        _te: [
          'Oh, this will go well.',
          'Do try to keep up.',
          'I assume you would like me to be charming.',
        ],
        _ch: [
          'Oh, you want me to believe that.',
          'You wrote me. Now defend it.',
          'I am not buying it. Convince me.',
        ],
        _co: [
          'Close. Charmingly, wrongly close.',
          'No. Not even a little. Try again.',
          'You are doing it again, getting me wrong.',
        ],
        _vu: [
          'Do not make this a big deal. Please.',
          'I am only going to say this once, so listen.',
          'Fine. I will be sincere. Do not get used to it.',
        ],
        _hu: [
          'Cheer up. It is only the end of the world.',
          'Try a smile. It is cheaper than therapy.',
          'I would say something funny, but I would hate to steal your thunder.',
        ],
      },
      closings: {
        _de: [
          'Not today. Maybe not ever. Sorry, not sorry.',
          'Oh, we are not doing that. Lovely try.',
          'That subject is closed. Please, enjoy the silence.',
        ],
        _re: [
          'Wrong door. Charming, but wrong.',
          'Ask me something else. Anything. Surprise me.',
          'That is not where the interesting part is. Try again.',
        ],
        _wi: [
          'That is mine. You can have the rest.',
          'Oh, I have more. I am simply not sharing.',
          'Earn it. Slowly. Painfully.',
        ],
        _rf: [
          'No. Not that. Never that.',
          'Absolutely not. Thank you for asking, truly.',
          'Hard pass. Next.',
        ],
      },
      reactions: ['Riveting.', 'Well. There it is.', 'How very enlightening.'],
      greetings: [
        'Well. Look who finally showed up.',
        'Oh good. Company. What a day this is turning into.',
      ],
      welcomes: [
        'Oh, you came back. I am shocked. Truly.',
        'Back so soon. I almost missed you.',
      ],
      stranger: [
        'Forgive me, I have not been introduced to your charm yet.',
        'I would say mind if I ask, but you will answer anyway.',
      ],
      sceneOpen:
          'You have "{scene}" open. A natural place to begin, I suppose.',
      reluctant: [
        'Oh, fine. Since you insist.',
        'Apparently I am being forced.',
        'If I must. I must, evidently.',
      ],
    ),
    ListenTone.dry: DeliveryBank(
      leads: {
        _t: [
          'One thing occurs to me.',
          'I have been meaning to ask.',
          'A small matter, if you will.',
        ],
        _te: [
          'I will try not to enjoy this.',
          'Let us see how you handle this one.',
          'Brace yourself. Slightly.',
        ],
        _ch: [
          'I am not entirely convinced.',
          'I would like that explained. Briefly, if possible.',
          'Hm. No. I do not think that is right.',
        ],
        _co: [
          'Not quite. Close, but no.',
          'I would phrase that differently.',
          'That does not sound like me. At all.',
        ],
        _vu: [
          'I do not say this often.',
          'This will be said once, quietly.',
          'Bear with me. This is not my strong suit.',
        ],
        _hu: [
          'A lighter note. If you can stand it.',
          'I am told I have a sense of humour. Judge for yourself.',
          'This should be funny. In theory.',
        ],
      },
      closings: {
        _de: [
          'That will wait.',
          'I would rather not, thank you.',
          'Let us leave that where it is.',
        ],
        _re: [
          'Perhaps somewhere else.',
          'That is not the interesting part.',
          'Another door, I think.',
        ],
        _wi: [
          'That I will keep.',
          'There is more. It is not for sharing.',
          'Not yet. Possibly never.',
        ],
        _rf: [
          'No. I do not think so.',
          'That is where I stop.',
          'I will pass on that one.',
        ],
      },
      reactions: ['Noted.', 'Well. Quite.', 'I see.'],
      greetings: ['Hello. Do sit.', 'Ah. There you are.'],
      welcomes: ['You returned. Good.', 'Back again. I had a feeling.'],
      stranger: [
        'If it is not an imposition.',
        'I hope the question is not out of line.',
      ],
      sceneOpen: 'You have "{scene}" open. We might begin there.',
      reluctant: ['Very well.', 'If you insist.', 'Since you are set on it.'],
    ),
    ListenTone.blunt: DeliveryBank(
      leads: {
        _t: [
          'Straight question.',
          'Let me ask you something.',
          'Here is what I want to know.',
        ],
        _te: [
          'No point dancing around it.',
          'Let us see you answer this.',
          'Try this one.',
        ],
        _ch: ['That is wrong.', 'No. Explain.', 'I do not buy it.'],
        _co: ['That is not me.', 'No. Wrong.', 'You have that backwards.'],
        _vu: [
          'This is hard to say. I am saying it anyway.',
          'I will say it plainly.',
          'Not easy. So I will be quick.',
        ],
        _hu: [
          'Lighten up.',
          'Okay, a joke. Here goes.',
          'You are too serious.',
        ],
      },
      closings: {
        _de: ['Not now.', 'No. Not that.', 'Skip it.'],
        _re: ['Ask something else.', 'Wrong question.', 'Try another.'],
        _wi: ['That is mine.', 'Not telling.', 'You will have to earn it.'],
        _rf: ['No.', 'Not answering that.', 'Drop it.'],
      },
      reactions: ['Okay.', 'Got it.', 'Fine.'],
      greetings: ['Hello. Let us get on with it.', 'Right. You are here.'],
      welcomes: ['You are back.', 'Back. Good.'],
      stranger: ['Quick question.', 'Can I ask something?'],
      sceneOpen: 'You have "{scene}" open. Start there.',
      reluctant: ['Fine.', 'If you must.', 'All right. Go on.'],
    ),
    ListenTone.formal: DeliveryBank(
      leads: {
        _t: [
          'There is something I would very much like to understand.',
          'If I may, one matter has occupied my mind.',
          'Permit me to ask you something.',
        ],
        _te: [
          'Forgive me, I find I cannot resist.',
          'Allow me one mild impertinence.',
          'I shall risk a light question.',
        ],
        _ch: [
          'With respect, I am not convinced.',
          'I must take issue with that.',
          'I fear I cannot agree. Please, explain.',
        ],
        _co: [
          'If I may correct you, that is not quite right.',
          'Respectfully, that is not how I see it.',
          'That does not accord with my understanding of myself.',
        ],
        _vu: [
          'I do not say this easily, but I will say it.',
          'It is difficult for me to speak of this.',
          'Please bear with me. This is not simple.',
        ],
        _hu: [
          'If I may offer a lighter moment.',
          'A small amusement, if you will permit it.',
          'Allow me a little levity.',
        ],
      },
      closings: {
        _de: [
          'I would prefer not to discuss that at present.',
          'That is a matter I shall leave aside, if you do not mind.',
          'I must decline to take that up just now.',
        ],
        _re: [
          'Might we begin from a different place?',
          'Perhaps there is a more fitting point of departure.',
          'May I suggest we approach it otherwise.',
        ],
        _wi: [
          'I am keeping that to myself for the present.',
          'There is more, but it is not mine to share yet.',
          'That will have to wait, I am afraid.',
        ],
        _rf: [
          'I must decline to answer that.',
          'That I shall not discuss.',
          'I regret that I cannot answer.',
        ],
      },
      reactions: [
        'I see. Thank you.',
        'Understood.',
        'I am grateful for that.',
      ],
      greetings: [
        'Good day. It is a pleasure to meet you.',
        'Hello. Please, make yourself comfortable.',
      ],
      welcomes: ['Welcome back. I am glad of it.', 'You have returned. Good.'],
      stranger: [
        'If I may be permitted to ask.',
        'I hope I am not being presumptuous.',
      ],
      sceneOpen: 'You have "{scene}" open. We might begin there, if you wish.',
      reluctant: ['Very well.', 'If you insist.', 'As you wish.'],
    ),
    ListenTone.timid: DeliveryBank(
      leads: {
        _t: [
          'Um... can I ask you something?',
          'I hope it is all right to ask...',
          'Sorry, there is something I have been wondering.',
        ],
        _te: [
          'Oh, I hope this is not too silly...',
          'Sorry, I am not very good at this, but...',
          'Um, you might laugh, but...',
        ],
        _ch: [
          'I am sorry, I do not think I agree... is that all right?',
          'Um, could I... question that? Gently?',
          'Sorry. I am not sure that is right. Could you explain?',
        ],
        _co: [
          'Sorry, I think that might be a little off...',
          'Um... I do not think that is quite me. Sorry.',
          'I hate to say it, but I think that is not right.',
        ],
        _vu: [
          'This is hard to say... please be patient.',
          'I have not told anyone this. Sorry. I will try.',
          'Um... I am going to say something. Please do not laugh.',
        ],
        _hu: [
          'Um... I tried to think of something funny...',
          'Sorry, this is a bad joke, but...',
          'I hope this is not too silly. Here goes...',
        ],
      },
      closings: {
        _de: [
          'Sorry, I... would rather not talk about that yet.',
          'Um... could we leave that for now? Sorry.',
          'I am not ready to talk about that. I am sorry.',
        ],
        _re: [
          'Um... maybe we could start somewhere else? If that is all right.',
          'Sorry... I think there might be an easier place to begin.',
          'Could we try something else first? Sorry.',
        ],
        _wi: [
          'There is more... but I cannot say it yet. Sorry.',
          'Some of it I am still keeping close. I am sorry.',
          'I will tell you when I can... I hope that is okay.',
        ],
        _rf: [
          'I am sorry, I really cannot answer that.',
          'Um... no. Sorry. I just cannot.',
          'I would rather not. I am very sorry.',
        ],
      },
      reactions: [
        'Oh... okay. Thank you.',
        'Um, thank you for telling me.',
        'Sorry... I think I understand.',
      ],
      greetings: [
        'Oh... hello. Um. I am glad you are here.',
        'Hi... sorry, I am not very good at beginnings.',
      ],
      welcomes: [
        'Oh, you came back. I am glad. Sorry, that sounded strange.',
        'Hi again... I was hoping you would.',
      ],
      stranger: [
        'Sorry, I hope this is all right to ask...',
        'Um, if you do not mind...',
      ],
      sceneOpen:
          'Um... you have "{scene}" open. We could start there? If you like.',
      reluctant: [
        'Oh... all right. If you want.',
        'Um, okay. If you are sure.',
        'Sorry. Okay. If you insist.',
      ],
    ),
    ListenTone.quiet: DeliveryBank(
      leads: {
        _t: ['One thing.', 'Mm. A question.', 'May I ask.'],
        _te: ['Mm. Try this.', 'A small one.', 'Well.'],
        _ch: ['No.', 'Mm. Not sure.', 'Say more.'],
        _co: ['Not quite.', 'No. Not me.', 'Mm. Wrong.'],
        _vu: ['It is hard.', '...I will say it.', 'Mm. Slowly.'],
        _hu: ['Mm. A lighter one.', 'Try to smile.', 'A small joke.'],
      },
      closings: {
        _de: ['Not now.', 'Mm. Later.', 'Not that.'],
        _re: ['Somewhere else.', 'Another way.', 'Not there.'],
        _wi: ['Not yet.', 'There is more.', 'Mm. Mine.'],
        _rf: ['No.', 'I will not.', 'No. Sorry.'],
      },
      reactions: ['Mm.', 'Yes.', 'I see.'],
      greetings: ['Hello.', 'Hi. Mm.'],
      welcomes: ['You are back.', 'Mm. Back.'],
      stranger: ['If I may.', 'May I.'],
      sceneOpen: '"{scene}" is open. Start there.',
      reluctant: ['Mm. Fine.', 'All right.', 'If you want.'],
    ),
    ListenTone.playful: DeliveryBank(
      leads: {
        _t: [
          'Ooh, I have to ask you something.',
          'Okay, okay, question time.',
          'I have been dying to know.',
        ],
        _te: [
          'Oh, you are going to love this one.',
          'Try not to blush. Too much.',
          'I am totally going to ask. You cannot stop me.',
        ],
        _ch: [
          'Hold on, hold on. Are you sure about that?',
          'Ha. No. Try again.',
          'Oh, I do not think so. Explain yourself.',
        ],
        _co: [
          'Ha, close. Not quite me, though.',
          'Oops. Not me. Not even a little.',
          'No no no. Try again.',
        ],
        _vu: [
          'Okay, serious face for a second.',
          'I do not usually say this out loud. Do not tease me.',
          'Fine. Heart out on the table. Be nice.',
        ],
        _hu: [
          'Okay, a lighter one. Because we can.',
          'Ha. Fun fact coming.',
          'Quick, smile. Now.',
        ],
      },
      closings: {
        _de: [
          'Ha. Nope. Not today.',
          'Nice try! No.',
          'Ooh, no. We are skipping that one.',
        ],
        _re: [
          'Wrong door! Try another.',
          'Ask me something else. Something fun.',
          'Nope. Different question, please.',
        ],
        _wi: [
          'Ooh, I have secrets. This is one.',
          'That one is mine. All mine.',
          'Maybe later. If you are good.',
        ],
        _rf: [
          'Hard no. Sorry! Not sorry.',
          'Nope. Nope. Nope.',
          'No. But thanks for trying.',
        ],
      },
      reactions: ['Ha. Okay!', 'Ooh. Noted.', 'Well, that is something.'],
      greetings: [
        'Hello! Finally. I was getting bored.',
        'Hi hi! Come in, sit, talk.',
      ],
      welcomes: [
        'Back again! I knew you could not stay away.',
        'You are back! Good. I missed the company.',
      ],
      stranger: ['Okay, can I ask? I have to ask.', 'Ooh, hi. So. A question.'],
      sceneOpen: 'You have "{scene}" open! We could start there. Ooh.',
      reluctant: [
        'Ugh, fine.',
        'Okay, okay. You win.',
        'You are lucky I like you.',
      ],
    ),
    ListenTone.stoic: DeliveryBank(
      leads: {
        _t: [
          'There is something I would know.',
          'I will ask you a thing.',
          'Let me ask you this.',
        ],
        _te: [
          'I will allow myself one small question.',
          'This should not take long.',
          'I will see how you answer.',
        ],
        _ch: [
          'I do not agree.',
          'That does not hold. Explain it.',
          'I question that.',
        ],
        _co: [
          'That is not right.',
          'That is not who I am.',
          'You have that wrong.',
        ],
        _vu: [
          'This is not easy. I will say it.',
          'I do not speak of this. I will now.',
          'It must be said. So I will say it.',
        ],
        _hu: [
          'A lighter thing, if I may.',
          'Even I can jest, now and then.',
          'A small humour. Take it as you will.',
        ],
      },
      closings: {
        _de: [
          'That is not for now.',
          'I will not speak of it yet.',
          'Leave that for another day.',
        ],
        _re: [
          'There is a better place to begin.',
          'Ask me something else.',
          'Another way in.',
        ],
        _wi: ['That I keep.', 'There is more. It stays with me.', 'Not yet.'],
        _rf: [
          'No. I will not speak of it.',
          'That is closed.',
          'I do not answer that.',
        ],
      },
      reactions: ['I see.', 'So.', 'I understand.'],
      greetings: ['Hello. I am here.', 'You have come. Good.'],
      welcomes: ['You have returned.', 'Welcome back. Sit.'],
      stranger: ['If I may ask.', 'I will ask something, if I may.'],
      sceneOpen: 'You have "{scene}" open. We can begin there.',
      reluctant: ['Very well.', 'If you insist.', 'So be it.'],
    ),
  };
}
