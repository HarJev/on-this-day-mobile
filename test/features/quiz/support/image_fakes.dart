import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_image.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_downloader.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_preparation_exception.dart';
import 'session_fakes.dart';

Future<ui.Image> testImage({int width = 40, int height = 20}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xffd8d1c6),
  );
  canvas.drawCircle(
    ui.Offset(width / 2, height / 2),
    height / 3,
    ui.Paint()..color = const ui.Color(0xff2f5f8f),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> testImageBytes({int width = 40, int height = 20}) async {
  final image = await testImage(width: width, height: height);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

QuizDefinition imageQuiz({bool unique = true, bool daily = false}) {
  final questions = [
    for (var i = 0; i < 5; i++)
      (() {
        final q =
            sessionQuestion(i, QuizQuestionType.imageIdentification)
                as ImageIdentificationQuestion;
        return ImageIdentificationQuestion(
          id: q.id,
          difficulty: q.difficulty,
          prompt: q.prompt,
          explanation: q.explanation,
          sources: q.sources,
          options: q.options,
          correctOptionId: q.correctOptionId,
          image: QuizImage(
            url: Uri.parse('https://example.org/${unique ? i : 0}.png'),
            altText: 'A blue circular form on a pale field',
            source: 'Fixture archive',
            sourceUrl: q.image.sourceUrl,
            attribution: 'Test artwork',
            creator: 'Test fixture',
            license: 'CC0',
            licenseUrl: q.image.licenseUrl,
          ),
        );
      })(),
  ];
  return daily
      ? DailyQuizDefinition(
          questionCount: 5,
          questions: questions,
          challengeId: 'daily-fixture',
          date: QuizDate('2026-09-13'),
          displayDate: 'Sep 13',
          duration: const Duration(seconds: 120),
        )
      : QuickPlayQuizDefinition(
          questionCount: 5,
          questions: questions,
          selection: QuizSelection(displayName: 'Mixed'),
          questionTimeLimits: {
            for (final q in questions) q.id: const Duration(seconds: 30),
          },
          timingEnabledByDefault: true,
        );
}

class BytesDownloader implements QuizImageDownloader {
  BytesDownloader(this.bytes);
  final Uint8List bytes;
  int calls = 0;
  @override
  Future<Uint8List> download(
    Uri url,
    QuizImageCancellation cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
  }) async {
    calls++;
    cancellation.check();
    if (bytes.length > maxBytes) {
      throw const QuizImagePreparationException(QuizImageFailure.encodedLimit);
    }
    reserveBytes(bytes.length);
    return bytes;
  }
}
