/// The lines every tone used to share, in each tone's own voice: the remark on a
/// kind of feeling, the callback to something said before, and the offer of another
/// topic when a character closes one.
///
/// Same rules as [MannerBanks]: authored, public through the phrase audits, and no
/// line states a fact about the story. A remark names a feeling in general, never
/// this character's reason for it.
library;

import '../voice/topic_boundaries.dart';
import 'lexicon.dart';
import 'listening.dart';

class SharedBank {
  const SharedBank({
    required this.reflections,
    required this.contrast,
    required this.back,
    required this.backCount,
    required this.doorways,
  });

  /// Two remarks for each [EmotionFamily], in the order the enum lists them.
  final List<List<String>> reflections;
  final List<String> contrast;

  /// Has `{W}`: the word the author used again.
  final String back;

  /// Has `{O}` (second, third…) and `{W}`.
  final String backCount;

  /// Two lines for each [TopicAccess], in the order the enum lists them.
  final List<List<String>> doorways;

  List<String> reflection(EmotionFamily f) => reflections[f.index];
  List<String> doorway(TopicAccess a) => doorways[a.index];

  Iterable<String> get all => [
    for (final r in reflections) ...r,
    ...contrast,
    back,
    backCount,
    for (final d in doorways) ...d,
  ];
}

class MannerShared {
  const MannerShared._();

  static SharedBank? of(ListenTone t) => _banks[t];

  static Set<String> get phrases => {for (final b in _banks.values) ...b.all};

  static const _banks = <ListenTone, SharedBank>{
    ListenTone.sardonic: SharedBank(
      reflections: [
        [
          'Fear. Always so keen to point at something.',
          'Fear is easier once it has a face. Convenient.',
        ],
        [
          'Anger is never about the thing it claims to be about.',
          'Anger, how original. There is usually something softer under it.',
        ],
        [
          'Grief keeps terrible hours.',
          'Grief is love with nowhere to go. Lovely design, that.',
        ],
        [
          'Shame hides beautifully. It is the best at it.',
          'Shame makes people very quiet. Pity it never lasts.',
        ],
        [
          'Tenderness. Heaven forbid anyone say it out loud.',
          'Caring is easy to feel and mortifying to show.',
        ],
        [
          'Joy. Do savour it, it never stays long.',
          'Something light for once. Do not tell anyone.',
        ],
        [
          'Hope is annoyingly stubborn.',
          'Hope asks far more of a person than giving up does. Rude.',
        ],
        [
          'Courage is much easier to name than to do.',
          'Courage always looks smaller from the inside. Funny, that.',
        ],
        [
          'Alone and lonely are not the same. Sadly.',
          'Loneliness gets louder at night. Show-off.',
        ],
        [
          'Envy is usually something else wearing a bad mask.',
          'Envy points at what someone wants. Subtle as a brick.',
        ],
        ['Pride costs a fortune.', 'Pride holds a lot up. Mostly itself.'],
        [
          'Relief shows what was being held. Dramatically.',
          'Relief usually arrives with a side of grief. Typical.',
        ],
        [
          'Not knowing is its own weight. Thrilling.',
          'Confusion often means two true things pulling. Rude of them.',
        ],
      ],
      contrast: [
        'Both can be true. Dreadful, is it not.',
        'Holding both is harder than choosing. Naturally.',
      ],
      back: '{W} again. Do keep up, you said that earlier.',
      backCount: 'The {O} time {W} has come up. Not that I am counting.',
      doorways: [
        [
          'Ask me about my days. Riveting, I know.',
          'Ask me about everyday things. I will try to stay awake.',
        ],
        [
          'Ask me about the people in my life. They are a delight.',
          'I will talk about where I come from. Brace yourself.',
        ],
        [
          'Ask me what scares me. Go on, I dare you.',
          'I will talk about what troubles me. Briefly.',
        ],
        [
          'We can talk about what hurt me, if you really must.',
          'I will talk about the hard things. Do not look so pleased.',
        ],
        [
          'Ask me anything. Just not that. Never that.',
          'Anything but that one. You are welcome.',
        ],
      ],
    ),
    ListenTone.dry: SharedBank(
      reflections: [
        [
          'Fear tends to point at something.',
          'Fear is easier to manage once it has a shape.',
        ],
        [
          'Anger is rarely about only one thing.',
          'There is usually something softer under anger.',
        ],
        [
          'Grief does not observe office hours.',
          'Grief is love with nowhere to go. An inefficient arrangement.',
        ],
        [
          'Shame is very good at not being found.',
          'Shame makes people quieter than they intend.',
        ],
        [
          'That sort of care is hard to say aloud.',
          'Tenderness is easy to feel and awkward to show.',
        ],
        [
          'Something light. A welcome change.',
          'Joy is easier to miss than pain.',
        ],
        [
          'Hope persists, against advice.',
          'Hope is the more demanding option. Giving up is cheaper.',
        ],
        [
          'Courage is far easier to admire than to perform.',
          'Courage looks smaller from the inside.',
        ],
        [
          'Being alone and being lonely are different matters.',
          'Loneliness gets louder at night.',
        ],
        [
          'Envy is usually something else in costume.',
          'Envy is a rather candid list of what one wants.',
        ],
        ['Pride is expensive to maintain.', 'Pride holds a good deal up.'],
        [
          'Relief shows what was being held.',
          'Relief tends to bring a little grief along, uninvited.',
        ],
        [
          'Not knowing is a weight of its own.',
          'Confusion often means two true things pulling.',
        ],
      ],
      contrast: [
        'Both can be true. Inconveniently.',
        'Holding both is harder than choosing.',
      ],
      back: '{W} again. You said as much earlier.',
      backCount: 'That is the {O} time {W} has come up.',
      doorways: [
        [
          'Ask me about my days, instead.',
          'Ask me about everyday things. They are dull but safe.',
        ],
        [
          'Ask me about the people in my life. Some are tolerable.',
          'I will tell you where I come from. It is not far.',
        ],
        [
          'Ask me what I am afraid of.',
          'I will discuss what troubles me. Briefly.',
        ],
        [
          'We can discuss what hurt me, if you insist.',
          'I will discuss the hard things. Once.',
        ],
        ['Ask anything. Except that, naturally.', 'Anything but that one.'],
      ],
    ),
    ListenTone.blunt: SharedBank(
      reflections: [
        [
          'Fear points at something. Find it.',
          'Name the fear. It gets smaller.',
        ],
        [
          'Anger is never about just one thing.',
          'Under anger, there is usually something softer.',
        ],
        [
          'Grief does not keep a schedule.',
          'Grief is love with no place to land.',
        ],
        ['Shame hides. It hides well.', 'Shame makes people quiet.'],
        [
          'Caring is hard to say out loud.',
          'Tenderness is easy to feel. Hard to show.',
        ],
        ['Good to hear something light.', 'Joy slips by. Notice it.'],
        ['Hope will not quit.', 'Hope takes more than giving up does.'],
        [
          'Courage is easier to say than to do.',
          'Courage looks smaller from inside.',
        ],
        ['Alone is not the same as lonely.', 'Loneliness is worse at night.'],
        ['Envy is something else underneath.', 'Envy tells you what you want.'],
        ['Pride costs you.', 'Pride holds a lot up.'],
        [
          'Relief shows what you were holding.',
          'Relief brings grief with it, often.',
        ],
        [
          'Not knowing is heavy.',
          'Confusion means two true things are pulling.',
        ],
      ],
      contrast: [
        'Both can be true.',
        'Holding both is harder than picking one.',
      ],
      back: '{W} again. You said that already.',
      backCount: '{W}. That is the {O} time.',
      doorways: [
        ['Ask about my day.', 'Ask about everyday things.'],
        ['Ask about the people in my life.', 'I can tell you where I am from.'],
        ['Ask what I am afraid of.', 'I can say what bothers me.'],
        ['Ask about what hurt me. Fine.', 'I can do the hard things. Ask.'],
        ['Anything. Not that, though.', 'Not that one.'],
      ],
    ),
    ListenTone.formal: SharedBank(
      reflections: [
        [
          'Fear, I find, usually points at something.',
          'Fear is more easily borne once it has a shape.',
        ],
        [
          'Anger is seldom about one thing alone.',
          'Beneath anger there is often something gentler.',
        ],
        [
          'Grief observes its own hours, not ours.',
          'Grief is what love does when it has nowhere to go.',
        ],
        [
          'Shame conceals itself with great skill.',
          'Shame makes people quieter than they intend to be.',
        ],
        [
          'Such care is difficult to speak aloud.',
          'Tenderness is easily felt and not easily shown.',
        ],
        [
          'It is pleasant to hear of something light.',
          'Joy is more readily missed than pain.',
        ],
        [
          'Hope is remarkably stubborn.',
          'Hope demands rather more of a person than resignation does.',
        ],
        [
          'Courage is easier to name than to practise.',
          'Courage tends to appear smaller from within.',
        ],
        [
          'To be alone is not the same as to be lonely.',
          'Loneliness grows louder at night.',
        ],
        [
          'Envy is often something else in disguise.',
          'Envy points toward what a person wants.',
        ],
        ['Pride has its cost.', 'Pride bears a great deal.'],
        [
          'Relief reveals what was being carried.',
          'Relief is frequently accompanied by a measure of grief.',
        ],
        [
          'Not knowing is a burden of its own.',
          'Confusion often means two true things are in tension.',
        ],
      ],
      contrast: [
        'Both may be true at once.',
        'To hold both is a harder task than to choose between them.',
      ],
      back: '{W} again. You mentioned it earlier as well.',
      backCount: 'That is the {O} time {W} has arisen.',
      doorways: [
        [
          'Perhaps ask me about my days instead.',
          'I would gladly speak of everyday things.',
        ],
        [
          'Ask me about the people in my life, if you wish.',
          'I shall speak of where I come from, gladly.',
        ],
        [
          'You might ask what I am afraid of, instead.',
          'I shall speak of what troubles me.',
        ],
        [
          'We may speak of what hurt me, if you wish.',
          'I will speak of the difficult things.',
        ],
        [
          'Ask me anything, save that one matter.',
          'Anything but that, I am afraid.',
        ],
      ],
    ),
    ListenTone.timid: SharedBank(
      reflections: [
        [
          'Fear... it usually points at something, I think. Sorry.',
          'I think fear gets easier when it has a shape... maybe.',
        ],
        [
          'Anger is rarely about just one thing... is it? Sorry.',
          'Under anger there is often something softer, I think...',
        ],
        [
          'Grief keeps its own hours... I think. I am sorry.',
          'Grief is... what love does with nowhere to go. Maybe.',
        ],
        [
          'Shame hides so well... sorry, I know a little about that.',
          'Shame makes people quieter than they mean to be. I think.',
        ],
        [
          'That kind of care is hard to say out loud... sorry.',
          'Tenderness is easy to feel and hard to show... I think.',
        ],
        [
          'Oh... it is good to hear something light. Sorry, is that all right?',
          'Joy is easier to miss than pain, I think...',
        ],
        [
          'Hope is stubborn... I hope. Sorry.',
          'Hope asks a lot... more than giving up. I think.',
        ],
        [
          'Courage is easier to name than to do... sorry.',
          'Courage looks smaller from the inside, maybe...',
        ],
        [
          'Being alone and being lonely are not the same... I think.',
          'Loneliness gets louder at night... sorry.',
        ],
        [
          'Envy is usually something else wearing a mask... I think.',
          'Envy points at what someone wants... maybe. Sorry.',
        ],
        [
          'Pride has a cost... I think. Sorry.',
          'Pride holds a lot up... maybe.',
        ],
        [
          'Relief shows what was being held... I think.',
          'Relief often comes with a little grief... sorry.',
        ],
        [
          'Not knowing is its own weight... sorry.',
          'Confusion often means two true things pulling... I think.',
        ],
      ],
      contrast: [
        'Both can be true... I think. Sorry.',
        'Holding both is harder than choosing... maybe.',
      ],
      back: '{W} again... sorry, you said that earlier. I noticed.',
      backCount: 'Um... that is the {O} time {W} has come up. Sorry.',
      doorways: [
        [
          'Um... maybe ask me about my days, instead? Sorry.',
          'We could talk about everyday things... if that is all right.',
        ],
        [
          'I... could talk about the people in my life. If you like.',
          'I could try talking about where I come from... sorry.',
        ],
        [
          'Maybe ask me what I am afraid of... instead? Sorry.',
          'I could talk about what troubles me... a little.',
        ],
        [
          'We could talk about what hurt me... if you really want. Sorry.',
          'I will try to talk about the hard things... slowly.',
        ],
        [
          'Ask me anything... just not that. I am so sorry.',
          'Anything but that one... please. Sorry.',
        ],
      ],
    ),
    ListenTone.quiet: SharedBank(
      reflections: [
        ['Fear points at something.', 'Fear needs a shape.'],
        ['Anger is rarely one thing.', 'Something softer under anger.'],
        ['Grief keeps its hours.', 'Love with nowhere to go.'],
        ['Shame hides.', 'Shame makes us quiet.'],
        ['Hard to say aloud.', 'Easy to feel. Hard to show.'],
        ['Good. Something light.', 'Joy slips past.'],
        ['Hope stays.', 'Hope asks a lot.'],
        ['Hard to do.', 'Looks smaller inside.'],
        ['Alone is not lonely.', 'Louder at night.'],
        ['Envy wears a mask.', 'Points at what you want.'],
        ['Pride is costly.', 'Holds a lot up.'],
        ['Relief shows the weight.', 'Some grief comes with it.'],
        ['Not knowing weighs.', 'Two true things pulling.'],
      ],
      contrast: ['Both. Mm.', 'Hard to hold both.'],
      back: '{W}. Again. Mm.',
      backCount: '{W}. The {O} time.',
      doorways: [
        ['Ask about today.', 'Everyday things.'],
        ['Ask about people I know.', 'Where I come from.'],
        ['Ask what I fear.', 'What troubles me.'],
        ['What hurt me. If you want.', 'The hard things.'],
        ['Anything. Not that.', 'Not that one.'],
      ],
    ),
    ListenTone.playful: SharedBank(
      reflections: [
        [
          'Ooh, fear! It always points at something. Sneaky.',
          'Fear is way less scary once it has a shape. Mostly.',
        ],
        [
          'Anger is never about just one thing. Never!',
          'Anger usually has something softer hiding underneath. Aww.',
        ],
        [
          'Grief keeps terrible hours. No manners.',
          'Grief is love with nowhere to go. Rude, honestly.',
        ],
        [
          'Shame hides so well. Sneaky little thing.',
          'Shame makes everyone go quiet. Weird, right?',
        ],
        [
          'Tenderness! Hard to say out loud, I know. Awkward.',
          'Caring is easy to feel and so hard to show. Silly, really.',
        ],
        [
          'Ooh, something light! I needed that.',
          'Joy is so easy to miss. Hold on to it!',
        ],
        [
          'Hope is stubborn. Like a cat.',
          'Hope asks way more than giving up does. Overachiever.',
        ],
        [
          'Courage is easier to name than do. Ha.',
          'Courage always looks smaller from the inside.',
        ],
        [
          'Alone and lonely are totally different. Annoying, right?',
          'Loneliness gets louder at night. Dramatic.',
        ],
        [
          'Envy is usually something else in a costume!',
          'Envy points at what someone wants. Ha, caught.',
        ],
        [
          'Pride costs a lot. Like, a lot.',
          'Pride holds a lot up. Heroic, really.',
        ],
        [
          'Relief shows what you were holding. Phew!',
          'Relief often brings a little grief. Rude plot twist.',
        ],
        [
          'Not knowing is its own weight. Ugh.',
          'Confusion often means two true things pulling. Tug of war!',
        ],
      ],
      contrast: [
        'Both can be true! Annoying, right?',
        'Holding both is harder than choosing. Overachiever.',
      ],
      back: '{W} again! You said that earlier. I noticed. Ha.',
      backCount: 'Ooh, the {O} time {W} has come up! Pattern alert.',
      doorways: [
        [
          'Ask me about my days! They are surprisingly fun.',
          'Ask me about everyday things. Fun ones.',
        ],
        [
          'Ask me about the people in my life!',
          'I will tell you where I come from. Brace yourself.',
        ],
        [
          'Ask me what I am afraid of. Gently!',
          'I will talk about what troubles me. A little.',
        ],
        [
          'We can go there, what hurt me. If you really want.',
          'I will talk about the hard stuff. Be nice.',
        ],
        [
          'Ask me anything! Just not that one. Seriously.',
          'Anything but that one. Nope.',
        ],
      ],
    ),
    ListenTone.stoic: SharedBank(
      reflections: [
        [
          'Fear points at something. Find what.',
          'Fear is lighter once it is named.',
        ],
        [
          'Anger is rarely about one thing.',
          'Beneath anger there is usually something softer.',
        ],
        ['Grief comes when it comes.', 'Grief is love, with no place to rest.'],
        [
          'Shame keeps itself hidden.',
          'Shame makes people quieter than they mean to be.',
        ],
        [
          'Such care is hard to say aloud.',
          'Tenderness is easy to feel and hard to show.',
        ],
        ['It is good to hear something light.', 'Joy is easily missed.'],
        ['Hope endures.', 'Hope asks more than giving up does.'],
        [
          'Courage is not the naming of it. It is the doing.',
          'Courage looks smaller from within.',
        ],
        ['To be alone is not to be lonely.', 'Loneliness is louder at night.'],
        [
          'Envy is another want, wearing a different face.',
          'Envy points at what a person wants.',
        ],
        ['Pride is paid for, in time.', 'Pride holds a great deal up.'],
        ['Relief shows what was carried.', 'Some grief follows relief.'],
        ['Not knowing is a weight.', 'Confusion is two true things pulling.'],
      ],
      contrast: [
        'Both are true. That is how it is.',
        'To hold both is harder than to choose one.',
      ],
      back: '{W} again. You said so earlier.',
      backCount: 'This is the {O} time {W} has come up.',
      doorways: [
        ['Ask me about my days.', 'I will speak of everyday things.'],
        [
          'Ask about the people who matter to me.',
          'I will say where I come from.',
        ],
        ['Ask me what I fear.', 'I will say what weighs on me.'],
        ['We can speak of what hurt me.', 'I will speak of the hard things.'],
        ['Ask me anything. Not that.', 'Anything but that one.'],
      ],
    ),
  };
}
