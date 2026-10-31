/// Reads a question the author typed into what is being asked: the kind of answer
/// wanted, the story things mentioned, and the verb. It does not look at the story.
library;

import 'extractor.dart';
import 'labels.dart';
import 'lexicon.dart';
import 'tagger.dart';
import 'tokenizer.dart';

enum QuestionIntent {
  location('retrieve_location'),
  time('retrieve_time'),
  manner('retrieve_manner'),
  attribute('retrieve_attribute'),
  agent('retrieve_agent'),
  object('retrieve_object'),
  yesNo('yes_no'),
  unsupported('unsupported');

  const QuestionIntent(this.label);
  final String label;

  static QuestionIntent parse(String label) => values.firstWhere(
    (i) => i.label == label,
    orElse: () => QuestionIntent.unsupported,
  );
}

class StoryQuestion {
  const StoryQuestion({
    required this.text,
    required this.intent,
    required this.entities,
    this.relation,
    this.attributeKind,
  });

  final String text;
  final QuestionIntent intent;

  /// Entity ids the question mentions.
  final List<String> entities;

  /// The verb asked about (lemma), or null for "where is the key".
  final String? relation;

  /// For attribute questions: `colour` or `material`.
  final String? attributeKind;

  Map<String, dynamic> toJson() => {
    'text': text,
    'intent': intent.label,
    'entities': entities,
    'relation': relation,
  };
}

class QuestionParser {
  QuestionParser(this.extractor, {Tagger? tagger})
    : _tagger = tagger ?? extractor.tagger;

  final FactExtractor extractor;
  final Tagger _tagger;
  static const _tokenizer = StoryTokenizer();

  static const _auxStart = {
    'did',
    'does',
    'do',
    'is',
    'was',
    'were',
    'are',
    'has',
    'had',
    'have',
    'can',
    'could',
    'will',
    'would',
    'should',
  };

  StoryQuestion parse(String text) {
    final sentences = _tagger.tag(_tokenizer.tokenize(text));
    final tokens = [for (final s in sentences) ...s.tokens];
    if (tokens.isEmpty) {
      return StoryQuestion(
        text: text,
        intent: QuestionIntent.unsupported,
        entities: const [],
      );
    }
    final first = tokens.first.lower;
    final second = tokens.length > 1 ? tokens[1].lower : '';
    var intent = QuestionIntent.unsupported;
    String? attributeKind;
    switch (first) {
      case 'where':
        intent = QuestionIntent.location;
      case 'when':
        intent = QuestionIntent.time;
      case 'how':
        intent =
            const {
              'many',
              'much',
              'long',
              'old',
              'far',
              'often',
            }.contains(second)
            ? QuestionIntent.unsupported
            : QuestionIntent.manner;
      case 'who' || 'whom':
        intent = QuestionIntent.agent;
      case 'what' || 'which':
        if (second == 'colour' || second == 'color') {
          intent = QuestionIntent.attribute;
          attributeKind = 'colour';
        } else if (second == 'material') {
          intent = QuestionIntent.attribute;
          attributeKind = 'material';
        } else if (_auxStart.contains(second)) {
          intent = QuestionIntent.object;
        }
      default:
        if (_auxStart.contains(first)) intent = QuestionIntent.yesNo;
    }

    String? relation;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.pos == Upos.verb) {
        // "end up" is a phrasal verb that means "be at the end": ask for the place.
        final next = i + 1 < tokens.length ? tokens[i + 1].lower : '';
        if (t.lemma == 'end' && next == 'up') break;
        relation = t.lemma;
        break;
      }
    }
    // "What did Iven take?" has no verb before the entity when the verb is last.
    return StoryQuestion(
      text: text,
      intent: intent,
      entities: extractor.entitiesIn(text),
      relation: relation,
      attributeKind: attributeKind,
    );
  }

  /// All lemmas a retrieval should treat as the asked verb.
  static Set<String> verbs(String relation) =>
      StoryLexicon.instance.synonyms(relation);
}
