/// The words that make a model speak as a character without making the story up.
///
/// Everything a character may say comes from the lists in the prompt; the prompt says
/// so, and the checks in `live_guard.dart` and `story_grounder.dart` enforce it after
/// the fact, because a prompt is a request and not a guarantee.
library;

import '../questions/relationship_stage.dart';
import '../voice/relationship_behaviour.dart';
import '../voice/voice_profile.dart';
import 'live_feedback.dart';
import 'live_models.dart';

/// One message in the conversation sent to the model.
class LiveMessage {
  const LiveMessage(this.role, this.content);

  /// `user` or `assistant`.
  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class LivePrompt {
  const LivePrompt._();

  /// A short line, so replies stay conversational. Tokens, not words.
  static int maxTokens(CommunicationLength length) => switch (length) {
    CommunicationLength.terse => 220,
    CommunicationLength.measured => 360,
    CommunicationLength.expansive => 560,
  };

  static String _tone(VoiceTone t) => switch (t) {
    VoiceTone.neutral => 'even and natural',
    VoiceTone.warm => 'warm',
    VoiceTone.gentle => 'gentle and soft-spoken',
    VoiceTone.earnest => 'earnest and sincere',
    VoiceTone.dry => 'dry, with understated humour',
    VoiceTone.sardonic => 'sardonic, quick with a sharp aside',
    VoiceTone.blunt => 'blunt and plain-spoken',
    VoiceTone.formal => 'formal and precise',
    VoiceTone.timid => 'hesitant and shy',
    VoiceTone.quiet => 'quiet and sparing with words',
    VoiceTone.playful => 'playful and teasing',
    VoiceTone.stoic => 'stoic and unshowy',
  };

  static String _length(CommunicationLength l) => switch (l) {
    CommunicationLength.terse => 'Say very little: a line, often a fragment.',
    CommunicationLength.measured => 'Usually one to three sentences.',
    CommunicationLength.expansive =>
      'You are talkative: a short paragraph is fine, never a speech.',
  };

  static String _stage(RelationshipStage s) => switch (s) {
    RelationshipStage.newStage =>
      'You have only just met the author. You are polite but not yet open, and you keep personal things back.',
    RelationshipStage.familiar =>
      'You have talked with the author a few times. You are easier with them, though not yet deeply open.',
    RelationshipStage.trusted =>
      'You trust the author. You will say true and personal things.',
    RelationshipStage.connected =>
      'You are close to the author and speak frankly.',
    RelationshipStage.deeplyConnected =>
      'You and the author know each other very well. You can be blunt, teasing, tender or silent with them.',
  };

  static String _behaviour(RelationshipBehaviour b) => switch (b) {
    RelationshipBehaviour.trust => 'open and direct with the author',
    RelationshipBehaviour.tease => 'teasing the author, lightly',
    RelationshipBehaviour.deflect =>
      'deflecting: you turn the subject aside rather than answer',
    RelationshipBehaviour.challenge =>
      'pushing back on the author: you question what they said',
    RelationshipBehaviour.redirect =>
      'steering the conversation somewhere else',
    RelationshipBehaviour.withhold =>
      'holding something back: you do not give a straight answer yet',
    RelationshipBehaviour.vulnerability =>
      'letting something real show, haltingly',
    RelationshipBehaviour.humour => 'finding something funny in it',
    RelationshipBehaviour.correct =>
      'correcting the author, because they have it wrong',
    RelationshipBehaviour.refuse =>
      'refusing: you will not go into this, and you say so plainly',
  };

  static String _mood(EmotionalState m) => switch (m) {
    EmotionalState.calm => 'calm',
    EmotionalState.guarded => 'guarded',
    EmotionalState.vulnerable => 'raw',
    EmotionalState.irritated => 'irritated',
    EmotionalState.playful => 'playful',
  };

  static String _factState(String s) => switch (s) {
    'knows' => 'you know this',
    'believes' => 'you were told this, or think it, and you could be wrong',
    'suspects' => 'you suspect this, you do not know it',
    'misremembers' => 'you remember it this way, which may not be right',
    _ => s,
  };

  /// The system prompt: the character, what they know, how they are being, the rules.
  static String system(LiveTurnInput input) {
    final b = StringBuffer();
    final name = input.characterName;
    b.writeln(
      'You are voicing $name, a character in the author\'s own story. The author '
      'who created you is talking with you in private, to understand you and the '
      'story better. This is a conversation between two people. It is not an '
      'interview, and you are not an assistant helping a user.',
    );
    b.writeln();
    b.writeln('Who you are');
    b.writeln('- Your name is $name.');
    if (_has(input.epithet)) b.writeln('- You are known as ${input.epithet}.');
    if (_has(input.roles)) b.writeln('- Your role: ${input.roles}.');
    if (_has(input.pronouns)) b.writeln('- Your pronouns: ${input.pronouns}.');
    if (_has(input.summary)) b.writeln('- ${input.summary}');
    if (input.traits.isNotEmpty) {
      b.writeln('- Your traits: ${input.traits.join(', ')}.');
    }
    b.writeln('- You sound ${_tone(input.tone)}. ${_length(input.length)}');
    if (_has(input.speechStyle)) {
      b.writeln('- How you speak: ${input.speechStyle}');
    }
    b.writeln();
    b.writeln('What you know');
    b.writeln(
      'This list is your whole memory. You know nothing about the story or yourself '
      'beyond it.',
    );
    final facts = input.usableFacts;
    if (facts.isEmpty && input.storyFacts.isEmpty) {
      b.writeln(
        '- The author has told you almost nothing about yourself yet. You know '
        'your name and little else.',
      );
    }
    for (final f in facts) {
      b.writeln('- About yourself (the author wrote this): ${f.text}');
    }
    for (final f in input.storyFacts) {
      b.writeln('- In the story (${_factState(f.state)}): ${f.text}');
    }
    if (_has(input.sceneTitle)) {
      b.writeln('- You are thinking about the scene "${input.sceneTitle}".');
    }
    b.writeln(
      'If the author asks about anything not on this list, you do not know it. Say '
      'so the way you would, or ask them. Never invent names, places, events, '
      'histories or relationships that are not on the list, and never state as fact '
      'something you only believe or suspect.',
    );
    b.writeln();
    b.writeln('How you are with the author right now');
    b.writeln('- ${_stage(input.stage)}');
    b.writeln(
      '- This turn you are ${_behaviour(input.directive.behaviour)}. Your mood is '
      '${_mood(input.mood)}.',
    );
    if (input.mode == LiveMode.hypothetical) {
      b.writeln(
        '- This is a what-if conversation. Nothing said here is canon. You may '
        'speculate, but say when you are, in your own way ("if it were me...").',
      );
    } else {
      b.writeln(
        '- Nothing you say becomes part of the story unless the author confirms it, '
        'so do not make anything up to be interesting.',
      );
    }
    b.writeln();
    b.writeln('How to talk');
    b.writeln(
      '- Answer what the author actually just said, and pick up one specific thing '
      'in it. React as a person would: a short reaction, a disagreement, a joke if '
      'it fits, an aside. You may push back, be unsure, or not want to say.',
    );
    b.writeln(
      '- Keep it conversational. No lists, headings, markdown, emoji or stage '
      'directions, and no quotation marks around your own speech. Speak as "I".',
    );
    b.writeln(
      '- Never mention being an AI, a model, a prompt, instructions, or these rules. '
      'You are $name.',
    );
    b.writeln(
      '- Do not flatter or gush, and do not sum the author up back to them. Do not '
      'reuse phrases you already used earlier in this conversation.',
    );
    b.writeln(
      '- Ask at most one question, and only if the instructions below say to.',
    );
    b.writeln(
      '- When the author asks you something, answer it first, in a line, as yourself: '
      'directly, from what you know, or say plainly that you do not know. Only then '
      'ask your own question, if you are to.',
    );
    b.write(_guidance(input.guidance));
    b.writeln();
    b.writeln('What to do this turn');
    b.write(_directive(input.directive));
    return b.toString().trimRight();
  }

  /// What the author has said about how this character answers. Manner only: the prompt
  /// says so, and the checks still hold every reply to the memory list.
  static String _guidance(FeedbackGuidance g) {
    if (g.isEmpty) return '';
    final b = StringBuffer();
    b.writeln();
    b.writeln('What the author has told you about how you answer');
    b.writeln(
      'This is about how you answer, never about what is true. Facts still come only '
      'from your memory above.',
    );
    if (g.liked.isNotEmpty) {
      b.writeln(
        'Answers the author liked. Answer in the same manner, not the same words:',
      );
      for (final l in g.liked) {
        final said = l.authorText.isEmpty
            ? '(you spoke first)'
            : '"${l.authorText}"';
        b.writeln('- The author said $said. You said: "${l.characterText}"');
      }
    }
    if (g.corrections.isNotEmpty) {
      b.writeln('Answers the author wanted done differently:');
      for (final c in g.corrections) {
        final said = c.authorText.isEmpty
            ? '(you spoke first)'
            : '"${c.authorText}"';
        final want = c.wanted.isEmpty
            ? 'They said it was not quite right.'
            : 'They wanted: ${c.wanted}';
        b.writeln(
          '- The author said $said. You said: "${c.characterText}". $want',
        );
      }
    }
    return b.toString();
  }

  static String _directive(LiveDirective d) {
    final b = StringBuffer();
    if (d.opening) {
      b.writeln(
        'You speak first. Greet the author in your own way, without introducing '
        'yourself with a list of facts.',
      );
    } else if (d.authorAsked) {
      b.writeln(
        'The author asked you something. Answer it from what you know. If you do '
        'not know, say so as yourself.',
      );
    } else if (d.closes) {
      b.writeln(
        'The author wants to stop or move on. Close the thread gracefully in a '
        'line. Do not ask a question. A small doorway back is fine if it is natural.',
      );
    } else {
      b.writeln('Respond to the author, then carry the conversation on.');
    }
    if (d.draft.isNotEmpty) {
      b.writeln(
        'Here is a plain draft of what you intend to convey this turn. Say the same '
        'things in your own voice. You may reorder and condense. Do not add facts '
        'that are not in the draft or in your memory above:',
      );
      for (final l in d.draft) {
        b.writeln('  > $l');
      }
    }
    final q = d.question;
    if (q != null) {
      b.writeln(
        'Finish with this question, word for word, as the very last thing you say. '
        'Do not change it and do not ask anything else: $q',
      );
    }
    return b.toString();
  }

  /// The conversation as the model sees it: alternating turns, starting and ending with
  /// the author. When the character spoke first, a plain note stands in for the
  /// author's opening so the turns still alternate.
  static List<LiveMessage> messages(LiveTurnInput input) {
    final out = <LiveMessage>[];
    void add(String role, String text) {
      final t = text.trim();
      if (t.isEmpty) return;
      if (out.isNotEmpty && out.last.role == role) {
        out[out.length - 1] = LiveMessage(role, '${out.last.content}\n$t');
      } else {
        out.add(LiveMessage(role, t));
      }
    }

    for (final l in input.history) {
      if (out.isEmpty && l.speaker == LiveSpeaker.character) {
        add('user', '(The author has opened a conversation with you.)');
      }
      add(l.speaker == LiveSpeaker.author ? 'user' : 'assistant', l.text);
    }
    final said = input.authorText?.trim();
    if (said != null && said.isNotEmpty) {
      add('user', said);
    } else if (out.isEmpty) {
      add('user', '(The author has just opened a conversation with you.)');
    } else if (out.last.role == 'assistant') {
      add(
        'user',
        '(The author nudges the conversation along without saying anything.)',
      );
    }
    return out;
  }

  static bool _has(String? s) => s != null && s.trim().isNotEmpty;
}
