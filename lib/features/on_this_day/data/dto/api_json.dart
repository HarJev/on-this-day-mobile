Map<String, Object?> requiredObject(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) {
    return value;
  }

  throw FormatException('Expected "$key" to be an object.');
}

List<Map<String, Object?>> requiredObjectList(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value is List) {
    return value
        .map((item) {
          if (item is Map<String, Object?>) {
            return item;
          }

          throw FormatException('Expected "$key" to contain objects.');
        })
        .toList(growable: false);
  }

  throw FormatException('Expected "$key" to be a list.');
}

String requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException('Expected "$key" to be a non-empty string.');
}

String? optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value.isEmpty ? null : value;
  }

  throw FormatException('Expected "$key" to be a string.');
}

Uri requiredUri(Map<String, Object?> json, String key) {
  final value = requiredString(json, key);
  return Uri.parse(value);
}

Uri? optionalUri(Map<String, Object?> json, String key) {
  final value = optionalString(json, key);
  return value == null ? null : Uri.parse(value);
}
