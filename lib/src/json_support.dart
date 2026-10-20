/// Small helpers for reading stored shapes tolerantly.
///
/// Every stored model in the engine reads the same way: a missing field or a value
/// this version does not know reads as a default, and what cannot be read at all
/// reads as nothing. Never a throw on stored data, because stored data outlives
/// the version that wrote it.
library;

/// The value of [values] named [raw], or [fallback].
T enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

/// The value of [values] named [raw], or null.
T? enumByNameOrNull<T extends Enum>(List<T> values, Object? raw) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}

/// The strings in [raw], dropping anything that is not one.
List<String> stringList(Object? raw) => raw is List
    ? [
        for (final e in raw)
          if (e is String) e,
      ]
    : const [];

/// [raw] as a UTC time, or null.
DateTime? readTime(Object? raw) =>
    raw is String ? DateTime.tryParse(raw) : null;

/// [value] as stored text.
String? writeTime(DateTime? value) => value?.toUtc().toIso8601String();
