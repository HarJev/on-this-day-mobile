import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/navigation/source_launcher.dart';
import '../../domain/quiz_image.dart';
import '../../domain/quiz_source.dart';
import '../images/prepared_quiz_images.dart';
import 'quiz_source_row.dart';

/// Owns a clone while RawImage is buildable. Session release cannot invalidate it.
///
/// Image credits often name the subject (a sitter, artwork title, or
/// filename), so they are not built at all until [creditAvailable] is true,
/// after the question has a committed outcome. Only the neutral [QuizImage.
/// altText] describes the image while it can still be answered.
class QuizQuestionImage extends StatefulWidget {
  const QuizQuestionImage({
    super.key,
    required this.questionId,
    required this.images,
    required this.metadata,
    required this.launcher,
    required this.creditAvailable,
  });
  final String questionId;
  final PreparedQuizImages images;
  final QuizImage metadata;
  final SourceLauncher launcher;

  /// Whether the question has been answered, skipped, or timed out.
  final bool creditAvailable;

  static const pendingCreditMessage = 'Image credit after answering';
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
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height * 0.24).clamp(
                150.0,
                210.0,
              ),
            ),
            child: AspectRatio(
              aspectRatio: image.width / image.height,
              child: RawImage(image: image, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
      if (widget.creditAvailable)
        _ImageCredit(
          questionId: widget.questionId,
          metadata: widget.metadata,
          launcher: widget.launcher,
        )
      else
        const _PendingCredit(),
      const SizedBox(height: 4),
    ],
  );
}

/// Holds the credit row's place while the question is answerable. It is the
/// same compact tile as the credit row, disabled and without children or an
/// expand icon, so nothing shifts when the credit becomes available. To
/// accessibility services it is only the plain message: no button, state, or
/// expand hint, and no credit content exists in the tree to find.
class _PendingCredit extends StatelessWidget {
  const _PendingCredit();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('image-credit-pending'),
    container: true,
    label: QuizQuestionImage.pendingCreditMessage,
    excludeSemantics: true,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        enabled: false,
        showTrailingIcon: false,
        tilePadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        minTileHeight: 36,
        title: Text(
          QuizQuestionImage.pendingCreditMessage,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mutedGray),
        ),
        children: const [],
      ),
    ),
  );
}

class _ImageCredit extends StatelessWidget {
  const _ImageCredit({
    required this.questionId,
    required this.metadata,
    required this.launcher,
  });

  final String questionId;
  final QuizImage metadata;
  final SourceLauncher launcher;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      key: ValueKey('credit-$questionId'),
      tilePadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      minTileHeight: 36,
      title: Text('Image credit', style: Theme.of(context).textTheme.bodySmall),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(metadata.attribution),
        ),
        if (metadata.creator != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(metadata.creator!),
          ),
        QuizSourceRow(
          source: QuizSource(
            displayName: metadata.source,
            url: metadata.sourceUrl,
          ),
          launcher: launcher,
        ),
        QuizSourceRow(
          source: QuizSource(
            displayName: metadata.license,
            url: metadata.licenseUrl,
          ),
          launcher: launcher,
        ),
      ],
    ),
  );
}
