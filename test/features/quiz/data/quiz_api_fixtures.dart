Map<String, Object?> imageJson() => {
  'url': 'https://example.org/image.jpg',
  'altText': 'An archival object',
  'source': 'Museum',
  'sourceUrl': 'https://example.org/collection',
  'attribution': 'Museum collection',
  'creator': 'An artist',
  'license': 'CC0',
  'licenseUrl': 'https://example.org/license',
};

Map<String, Object?> questionJson(int index, {bool quickPlay = true}) {
  final type = [
    'multiple_choice',
    'true_false',
    'image_identification',
    'chronological_ordering',
    'multiple_choice',
  ][index % 5];
  return {
    'id': 'question-$index',
    'type': type,
    'difficulty': ['easy', 'medium', 'hard'][index % 3],
    'prompt': 'Question $index?',
    'explanation': 'Explanation $index.',
    'sources': [
      <String, Object?>{
        'displayName': 'Museum',
        'url': 'https://example.org/source',
      },
    ],
    if (quickPlay) 'timeLimitSeconds': [20, 20, 30, 45, 20][index % 5],
    if (type == 'image_identification') 'image': imageJson(),
    if (type == 'chronological_ordering') ...{
      'items': [
        for (final id in ['d', 'b', 'a', 'c'])
          <String, Object?>{'id': id, 'text': 'Item $id'},
      ],
      'correctOrderItemIds': ['a', 'b', 'c', 'd'],
    } else ...{
      'options': type == 'true_false'
          ? [
              <String, Object?>{'id': 'true', 'text': 'True'},
              <String, Object?>{'id': 'false', 'text': 'False'},
            ]
          : [
              for (final id in ['c', 'a', 'd', 'b'])
                <String, Object?>{'id': id, 'text': 'Option $id'},
            ],
      'correctOptionId': type == 'true_false' ? 'true' : 'a',
    },
  };
}

Map<String, Object?> quickJson({int count = 5, String? collectionId}) => {
  'mode': 'quick_play',
  'questionCount': count,
  'selection': <String, Object?>{
    'collectionId': collectionId,
    'displayName': collectionId == null ? 'Mixed' : 'World History',
  },
  'timer': <String, Object?>{'mode': 'per_question', 'enabledByDefault': true},
  'questions': List.generate(count, (i) => questionJson(i)),
};

Map<String, Object?> dailyJson({int count = 5}) => {
  'mode': 'daily',
  'questionCount': count,
  'assignmentQuestionCount': 20,
  'challengeId': 'daily-2026-08-24',
  'date': <String, Object?>{'isoDate': '2026-08-24', 'displayDate': 'Aug 24'},
  'timer': <String, Object?>{
    'mode': 'total',
    'durationSeconds': {5: 120, 10: 240, 20: 480}[count],
  },
  'questions': List.generate(count, (i) => questionJson(i, quickPlay: false)),
};

Map<String, Object?> catalogJson() => {
  'questionCounts': [5, 10, 20],
  'quickPlayTimerDefaultsSeconds': <String, Object?>{
    'multipleChoice': 20,
    'trueFalse': 20,
    'imageIdentification': 30,
    'chronologicalOrdering': 45,
  },
  'mixed': <String, Object?>{
    'publishedQuestionCount': 60,
    'supportedQuestionCounts': [5, 10, 20],
  },
  'collections': [
    for (final group in [
      'topic',
      'historical_period',
      'civilization',
      'conflict_or_movement',
    ])
      <String, Object?>{
        'id': group.replaceAll('_', '-'),
        'name': group,
        'group': group,
        'publishedQuestionCount': 12,
        'supportedQuestionCounts': [5, 10],
      },
  ],
};

Map<String, Object?> objectAt(Map<String, Object?> json, String key) =>
    json[key] as Map<String, Object?>;
List<Map<String, Object?>> objectsAt(Map<String, Object?> json, String key) =>
    (json[key] as List).cast<Map<String, Object?>>();
