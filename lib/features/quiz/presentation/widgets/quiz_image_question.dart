import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/navigation/source_launcher.dart';
import '../../domain/quiz_image.dart';
import '../../domain/quiz_source.dart';
import '../images/prepared_quiz_images.dart';
import 'quiz_source_row.dart';

/// Owns a clone while RawImage is buildable. Session release cannot invalidate it.
class QuizQuestionImage extends StatefulWidget {
  const QuizQuestionImage({
    super.key,
    required this.questionId,
    required this.images,
    required this.metadata,
    required this.launcher,
  });
  final String questionId;
  final PreparedQuizImages images;
  final QuizImage metadata;
  final SourceLauncher launcher;
  @override
  State<QuizQuestionImage> createState() => _QuizQuestionImageState();
}

class _QuizQuestionImageState extends State<QuizQuestionImage> {
  late final ui.Image image;
  @override
  void initState() {
    super.initState();
    image = widget.images.acquire(widget.questionId)!;
  }

  @override
  void dispose() {
    image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        image: true,
        label: widget.metadata.altText,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: AspectRatio(
              aspectRatio: image.width / image.height,
              child: RawImage(image: image, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('credit-${widget.questionId}'),
          tilePadding: EdgeInsets.zero,
          title: Text(
            'Image credit',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.metadata.attribution),
            ),
            if (widget.metadata.creator != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.metadata.creator!),
              ),
            QuizSourceRow(
              source: QuizSource(
                displayName: widget.metadata.source,
                url: widget.metadata.sourceUrl,
              ),
              launcher: widget.launcher,
            ),
            QuizSourceRow(
              source: QuizSource(
                displayName: widget.metadata.license,
                url: widget.metadata.licenseUrl,
              ),
              launcher: widget.launcher,
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ],
  );
}
