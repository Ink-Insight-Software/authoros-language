/// The shared AuthorOS language layer.
///
/// Two seams and a rule-based implementation of each: *delivery* puts a decided
/// question in a character's mouth, and *reading* turns an author's free text into
/// something an engine can use. Also the vocabulary they speak in: a character's
/// voice, how well the author knows them, and what they will talk about.
library;

export 'src/conversation/author_response.dart';
export 'src/language/character_answerer.dart';
export 'src/language/delivery_service.dart';
export 'src/language/dialogue.dart';
export 'src/language/language_layer.dart';
export 'src/language/lexicon.dart';
export 'src/language/listening.dart';
export 'src/language/manner_banks.dart';
export 'src/language/manner_shared.dart';
export 'src/language/response_reader.dart';
export 'src/language/voice_sample.dart';
export 'src/questions/character_question.dart';
export 'src/questions/interaction_mode.dart';
export 'src/questions/question_depth.dart';
export 'src/questions/relationship_stage.dart';
export 'src/voice/disagreement.dart';
export 'src/voice/relationship_behaviour.dart';
export 'src/voice/relationship_state.dart';
export 'src/voice/relationship_voice_composer.dart';
export 'src/voice/topic_boundaries.dart';
export 'src/voice/voice_profile.dart';
export 'src/model/chat_fallback.dart';
export 'src/model/chat_guard.dart';
export 'src/model/chat_models.dart';
export 'src/model/model_backed_chat.dart';
export 'src/model/model_exception.dart';
export 'src/model/own_model_client.dart';
