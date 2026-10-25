/// Story grounding: ask an author's own text a question and get an answer that says
/// whether it was stated, worked out, unknown or contradicted, with the exact words.
///
/// Stages, each replaceable and each inspectable on its own:
///   tokenize -> tag -> extract facts -> index -> parse question -> retrieve
/// Proposals (`proposals.dart`) are a separate, opt-in stage that never feeds the index.
library;

export 'answer.dart';
export 'entities.dart';
export 'extractor.dart' show ExtractionOutput, FactExtractor;
export 'facts.dart';
export 'index.dart';
export 'knowledge.dart';
export 'knowledge_question.dart';
export 'labels.dart';
export 'lexicon.dart' show StoryLexicon;
export 'proposals.dart';
export 'question.dart';
export 'retriever.dart' show StoryRetriever;
export 'tagger.dart' show RuleTagger, Tagger;
export 'tokenizer.dart' show StoryTokenizer;
