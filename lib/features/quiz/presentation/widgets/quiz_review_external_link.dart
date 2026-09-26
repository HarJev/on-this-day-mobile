import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/navigation/source_launcher.dart';

/// A self-contained external link. Its reserved feedback line prevents a
/// failure from moving the review's surrounding scroll content.
class QuizReviewExternalLink extends StatefulWidget {
  const QuizReviewExternalLink({
    super.key,
    required this.label,
    required this.url,
    required this.launcher,
    this.semanticsLabel,
  });

  final String label;
  final String? semanticsLabel;
  final Uri url;
  final SourceLauncher launcher;

  @override
  State<QuizReviewExternalLink> createState() => _QuizReviewExternalLinkState();
}

class _QuizReviewExternalLinkState extends State<QuizReviewExternalLink> {
  bool busy = false;
  bool failed = false;

  Future<void> open() async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    var opened = false;
    try {
      opened = await widget.launcher.open(widget.url);
    } catch (_) {
      // The safe retry treatment below intentionally excludes technical detail.
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      failed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        label: widget.semanticsLabel,
        excludeSemantics: widget.semanticsLabel != null,
        child: TextButton.icon(
          onPressed: busy ? null : open,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(widget.label),
        ),
      ),
      if (failed)
        Text(
          'Could not open link. Tap to retry.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mutedGray),
        ),
    ],
  );
}
