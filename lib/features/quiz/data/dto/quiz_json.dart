/// Typed JSON access with paths, without coercion or response-body diagnostics.
final class QuizJson {
  const QuizJson(this.value, [this.path = r'$']);
  final Map<String, Object?> value;
  final String path;

  Never invalid(String key, String expected) =>
      throw FormatException('$path.$key: expected $expected');

  String string(String key) {
    final v = value[key];
    if (v is! String) invalid(key, 'string');
    return v;
  }

  String? nullableString(String key) => value[key] == null ? null : string(key);

  int integer(String key) {
    final v = value[key];
    if (v is! int) invalid(key, 'integer');
    return v;
  }

  bool boolean(String key) {
    final v = value[key];
    if (v is! bool) invalid(key, 'boolean');
    return v;
  }

  QuizJson object(String key) {
    final v = value[key];
    if (v is! Map<String, Object?>) invalid(key, 'object');
    return QuizJson(v, '$path.$key');
  }

  List<Object?> list(String key) {
    final v = value[key];
    if (v is! List) invalid(key, 'array');
    return List<Object?>.of(v);
  }

  List<QuizJson> objects(String key) {
    final entries = list(key);
    return List.generate(entries.length, (i) {
      final entry = entries[i];
      if (entry is! Map<String, Object?>) invalid('$key[$i]', 'object');
      return QuizJson(entry, '$path.$key[$i]');
    });
  }

  List<int> integers(String key) => list(key).asMap().entries.map((e) {
    if (e.value is! int) invalid('$key[${e.key}]', 'integer');
    return e.value as int;
  }).toList();

  List<String> strings(String key) => list(key).asMap().entries.map((e) {
    if (e.value is! String) invalid('$key[${e.key}]', 'string');
    return e.value as String;
  }).toList();

  T enumValue<T>(String key, Map<String, T> values) {
    final result = values[string(key)];
    if (result == null) invalid(key, 'supported value');
    return result;
  }

  void expect(String key, String expected) {
    if (string(key) != expected) invalid(key, expected);
  }

  void prohibit(String key) {
    if (value.containsKey(key)) {
      invalid(key, 'field to be absent for this shape');
    }
  }

  Duration duration(String key) {
    final seconds = integer(key);
    // Avoid overflowing Dart's microsecond representation during conversion.
    if (seconds <= 0 || seconds > 9223372036854) {
      invalid(key, 'positive representable duration in seconds');
    }
    return Duration(seconds: seconds);
  }
}
