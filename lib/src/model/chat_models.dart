/// What a character is asked to say when it is not asking a story question: opening
/// a conversation, welcoming the author back, replying to a light remark, saying
/// goodbye. The same four moments the model is trained on (`model/common.py`).
library;

import '../voice/voice_profile.dart';

enum ChatMoment { opening, returning, chat, farewell }

class ChatRequest {
  const ChatRequest({
    required this.moment,
    this.authorLine = '',
    this.tone = VoiceTone.neutral,
    this.length = CommunicationLength.measured,
    this.seed = 0,
    this.turn = 0,
  });

  final ChatMoment moment;

  /// What the author just said. Empty for an opening or a returning.
  final String authorLine;

  /// How the character sounds. Sent to the model by name.
  final VoiceTone tone;
  final CommunicationLength length;

  /// For the authored fallback, so a turn replays exactly.
  final int seed;
  final int turn;
}

/// What came back.
class ChatReply {
  const ChatReply(this.text, {this.usedModel = false, this.fallback});

  /// One line for the character to say, or null when there is nothing to say
  /// (a farewell the model could not give, which has no authored line).
  final String? text;

  /// The model wrote it, and it passed every check.
  final bool usedModel;

  /// Why the authored line was used when a model was expected, else null.
  final String? fallback;
}
