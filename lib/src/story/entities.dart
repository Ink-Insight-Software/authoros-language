/// The things a story is about: the author's characters, and the items and places
/// found in the text. The registry is data the project supplies; the linker never
/// invents a character.
library;

import 'labels.dart';

/// A thing the author has defined. Characters carry the pronouns the author
/// recorded; `they` is a valid value, and an unset one means pronouns are not used
/// to resolve this character.
class ProjectEntity {
  const ProjectEntity({
    required this.id,
    required this.type,
    required this.names,
    this.pronouns,
  });

  factory ProjectEntity.fromJson(Map<String, dynamic> json) => ProjectEntity(
    id: json['id'] as String,
    type: EntityType.parse(json['type'] as String) ?? EntityType.other,
    names: [for (final n in json['names'] as List) n as String],
    pronouns: json['pronouns'] as String?,
  );

  final String id;
  final EntityType type;
  final List<String> names;
  final String? pronouns;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.label,
    'names': names,
    if (pronouns != null) 'pronouns': pronouns,
  };
}

class EntityRegistry {
  EntityRegistry(Iterable<ProjectEntity> entities)
    : entities = List.unmodifiable(entities) {
    for (final e in this.entities) {
      _byId[e.id] = e;
      for (final n in e.names) {
        _byName[n.toLowerCase()] = e;
      }
    }
  }

  final List<ProjectEntity> entities;
  final _byId = <String, ProjectEntity>{};
  final _byName = <String, ProjectEntity>{};

  ProjectEntity? byId(String id) => _byId[id];

  /// The entity whose name is [word] (case-insensitive), or null.
  ProjectEntity? byName(String word) => _byName[word.toLowerCase()];

  bool isName(String word) => _byName.containsKey(word.toLowerCase());

  /// Characters whose recorded pronoun is [pronoun] (`she`, `he`, `they`...).
  List<ProjectEntity> withPronoun(String pronoun) => [
    for (final e in entities)
      if (e.type == EntityType.character && e.pronouns == pronoun) e,
  ];

  /// The id an item or place gets from the words that name it: `item_key`,
  /// `place_chapel_floor`. The same words always give the same id, which is how a
  /// question finds what a passage said.
  static String idFor(EntityType type, List<String> lemmas) =>
      '${type.prefix}_${lemmas.map((l) => l.toLowerCase()).join('_')}';

  /// The pronoun that refers to a pronoun-form word: `him` is `he`.
  static String? subjectForm(String word) => switch (word.toLowerCase()) {
    'she' || 'her' || 'herself' => 'she',
    'he' || 'him' || 'himself' => 'he',
    'they' || 'them' || 'themselves' => 'they',
    'it' || 'itself' => 'it',
    'i' || 'me' || 'myself' => 'i',
    _ => null,
  };
}
