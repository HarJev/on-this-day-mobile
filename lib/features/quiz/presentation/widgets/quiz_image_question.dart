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
  Widget build(BuildContext context) {
    final maxHeight = widget.creditAvailable
        ? (MediaQuery.sizeOf(context).height * 0.2).clamp(130.0, 170.0)
        : (MediaQuery.sizeOf(context).height * 0.28).clamp(150.0, 250.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          image: true,
          label: widget.metadata.altText,
          child: ExcludeSemantics(
            // An ivory mat keeps portraits uncropped and framed.
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.softIvory,
                border: Border.all(color: AppColors.paleStone),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: AspectRatio(
                      aspectRatio: image.width / image.height,
                      child: RawImage(image: image, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.creditAvailable)
          _ImageCredit(
            key: ValueKey('credit-${widget.questionId}'),
            metadata: widget.metadata,
            launcher: widget.launcher,
          )
        else
          const _PendingCredit(),
        const SizedBox(height: 6),
      ],
    );
  }
}

const _creditRowHeight = 44.0;

/// Holds the credit row's place while the question is answerable, at the
/// same height as the credit row so nothing shifts once it is available. To
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
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _creditRowHeight),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 15, color: AppColors.mutedGray),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              QuizQuestionImage.pendingCreditMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The full credit behind one quiet row that expands in place.
class _ImageCredit extends StatefulWidget {
  const _ImageCredit({
    super.key,
    required this.metadata,
    required this.launcher,
  });

  final QuizImage metadata;
  final SourceLauncher launcher;

  @override
  State<_ImageCredit> createState() => _ImageCreditState();
}

class _ImageCreditState extends State<_ImageCredit> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final metadata = widget.metadata;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: 'Image credit',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _creditRowHeight),
              child: Row(
                children: [
                  const Icon(
                    Icons.photo_camera_outlined,
                    size: 15,
                    color: AppColors.mutedGray,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Image credit', style: textTheme.bodySmall),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.mutedGray,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(left: 21, bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        metadata.attribution,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.mutedGray,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                      if (metadata.creator != null)
                        Text(
                          metadata.creator!,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.mutedGray,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      QuizSourceRow(
                        source: QuizSource(
                          displayName: metadata.source,
                          url: metadata.sourceUrl,
                        ),
                        launcher: widget.launcher,
                      ),
                      QuizSourceRow(
                        source: QuizSource(
                          displayName: metadata.license,
                          url: metadata.licenseUrl,
                        ),
                        launcher: widget.launcher,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
